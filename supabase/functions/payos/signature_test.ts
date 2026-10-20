// Run: node supabase/functions/payos/signature_test.ts
import assert from "node:assert/strict";
import { sign } from "./signature.ts";

// Expected values from Python's hmac.new(key, query, sha256).hexdigest().
assert.equal(
  await sign(
    {
      returnUrl: "https://x.test/return",
      orderCode: 12,
      description: "ALLFITS",
      cancelUrl: "https://x.test/return",
      amount: 2000,
    },
    "secret",
  ),
  "d5b41a6440ad2d49807d3eca9c315ce4584f6dd02b0570a6695ad36919707910",
);
assert.equal(
  await sign({ orderCode: 7, desc: null, code: "00" }, "secret"),
  "45b8b46702d609d3dc2894ce69a7983c65adfb12991771adce2fe9b3ea90e0f7",
);
console.log("signature ok");
