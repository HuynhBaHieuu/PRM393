// payOS checkout for All Fits Premium. Setup and deploy: docs/payos.md.
//
//   POST /payos/create   (signed-in user)  -> { orderCode, checkoutUrl }
//   POST /payos/status   (signed-in user)  { orderCode } -> { status }
//   POST /payos/webhook  (payOS)           marks the order paid
//   GET  /payos/return   (browser)         page shown after paying
//
// Deployed with --no-verify-jwt because payOS calls the webhook without a
// Supabase token; create and status check the user's token themselves.
import { createClient } from "npm:@supabase/supabase-js@2";
import { sign } from "./signature.ts";

const PAYOS_API = "https://api-merchant.payos.vn";
const PRICE_VND = Number(Deno.env.get("PREMIUM_PRICE_VND") ?? 2000);
const PREMIUM_DAYS = Number(Deno.env.get("PREMIUM_DAYS") ?? 30);
// Unpaid links stop working after this long.
const LINK_MINUTES = 15;

function secret(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing secret ${name}`);
  return value;
}

const supabaseUrl = secret("SUPABASE_URL");
const admin = createClient(supabaseUrl, secret("SUPABASE_SERVICE_ROLE_KEY"));
const returnUrl = `${supabaseUrl}/functions/v1/payos/return`;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

async function payos(path: string, init: RequestInit = {}) {
  const response = await fetch(`${PAYOS_API}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      "x-client-id": secret("PAYOS_CLIENT_ID"),
      "x-api-key": secret("PAYOS_API_KEY"),
    },
  });
  const body = await response.json();
  if (body.code !== "00") {
    throw new Error(`payOS ${path}: ${body.code} ${body.desc}`);
  }
  return body.data;
}

async function markPaid(orderCode: number, amount: number) {
  const { error } = await admin.rpc("mark_payment_paid", {
    p_order_code: orderCode,
    p_amount: amount,
    p_days: PREMIUM_DAYS,
  });
  if (error) throw error;
}

async function create(userId: string) {
  const { data: row, error } = await admin
    .from("payments")
    .insert({ user_id: userId, amount: PRICE_VND })
    .select("order_code")
    .single();
  if (error) throw error;
  const orderCode = Number(row.order_code);
  // Banks not linked through payOS allow 9 characters of description.
  const signed = {
    amount: PRICE_VND,
    cancelUrl: returnUrl,
    description: "ALLFITS",
    orderCode,
    returnUrl,
  };
  const link = await payos("/v2/payment-requests", {
    method: "POST",
    body: JSON.stringify({
      ...signed,
      items: [
        {
          name: `All Fits Premium ${PREMIUM_DAYS} days`,
          quantity: 1,
          price: PRICE_VND,
        },
      ],
      expiredAt: Math.floor(Date.now() / 1000) + LINK_MINUTES * 60,
      signature: await sign(signed, secret("PAYOS_CHECKSUM_KEY")),
    }),
  });
  await admin
    .from("payments")
    .update({ checkout_url: link.checkoutUrl })
    .eq("order_code", orderCode);
  return json({ orderCode, checkoutUrl: link.checkoutUrl });
}

/** Asks payOS about a pending order, so Premium starts even without the webhook. */
async function status(userId: string, orderCode: number) {
  const { data: row, error } = await admin
    .from("payments")
    .select("status, user_id")
    .eq("order_code", orderCode)
    .maybeSingle();
  if (error) throw error;
  if (!row || row.user_id !== userId) return json({ error: "Not found" }, 404);
  if (row.status !== "PENDING") return json({ status: row.status });

  const link = await payos(`/v2/payment-requests/${orderCode}`);
  if (link.status === "PAID") {
    await markPaid(orderCode, link.amountPaid);
  } else if (link.status === "CANCELLED" || link.status === "EXPIRED") {
    await admin
      .from("payments")
      .update({ status: link.status })
      .eq("order_code", orderCode)
      .eq("status", "PENDING");
  }
  return json({ status: link.status });
}

async function webhook(request: Request) {
  const body = await request.json();
  const data = body?.data;
  if (
    !data ||
    (await sign(data, secret("PAYOS_CHECKSUM_KEY"))) !== body.signature
  ) {
    return json({ error: "Invalid signature" }, 400);
  }
  // payOS's test call when confirming the webhook URL uses an unknown order,
  // which markPaid ignores.
  if (body.code === "00" && data.code === "00") {
    await markPaid(Number(data.orderCode), Number(data.amount));
  }
  return json({ success: true });
}

function returnPage(url: URL) {
  const cancelled = url.searchParams.get("cancel") === "true";
  const text = cancelled
    ? "Payment cancelled. You can close this page and go back to All Fits."
    : "Thanks! Go back to All Fits: Premium starts as soon as the payment is confirmed.";
  return new Response(text, {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
}

Deno.serve(async (request) => {
  const url = new URL(request.url);
  const route = url.pathname.split("/").pop();
  try {
    if (request.method === "GET" && route === "return") return returnPage(url);
    if (request.method !== "POST") return json({ error: "Not found" }, 404);
    if (route === "webhook") return await webhook(request);

    const token = request.headers.get("Authorization")?.replace(/^Bearer /, "");
    const { data } = token
      ? await admin.auth.getUser(token)
      : { data: { user: null } };
    if (!data.user) return json({ error: "Sign in first" }, 401);
    if (route === "create") return await create(data.user.id);
    if (route === "status") {
      const { orderCode } = await request.json();
      return await status(data.user.id, Number(orderCode));
    }
    return json({ error: "Not found" }, 404);
  } catch (error) {
    console.error(error);
    return json({ error: "Payment service unavailable" }, 502);
  }
});
