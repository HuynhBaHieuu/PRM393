/**
 * payOS signature: lowercase hex HMAC-SHA256 of the fields sorted by key and
 * joined as `key=value&key=value`, with null as empty and arrays as JSON.
 * Signs payment requests and verifies webhooks (https://payos.vn/docs).
 */
export async function sign(
  data: Record<string, unknown>,
  checksumKey: string,
): Promise<string> {
  const query = Object.keys(data)
    .sort()
    .filter((key) => data[key] !== undefined)
    .map((key) => `${key}=${serialize(data[key])}`)
    .join("&");
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(checksumKey),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", key, encoder.encode(query));
  return [...new Uint8Array(mac)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function serialize(value: unknown): string {
  if (value === null || value === "null" || value === "undefined") return "";
  if (Array.isArray(value)) return JSON.stringify(value.map(sortKeys));
  return String(value);
}

function sortKeys(value: unknown): unknown {
  if (value === null || typeof value !== "object") return value;
  const record = value as Record<string, unknown>;
  return Object.fromEntries(
    Object.keys(record).sort().map((key) => [key, record[key]]),
  );
}
