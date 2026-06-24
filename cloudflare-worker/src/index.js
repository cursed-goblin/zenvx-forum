/**
 * ZenVX Supabase Proxy Worker
 *
 * Fronts ALL Supabase REST/Auth/Storage API calls so they pass through
 * Cloudflare (DDoS protection + rate limiting) instead of hitting the
 * Supabase origin directly.
 */

const SCHEME = "https://";

export default {
  async fetch(request, env) {
    const origin = request.headers.get("Origin") || "";
    const allowed = (env.ALLOWED_ORIGINS || "").split(",").map((s) => s.trim()).filter(Boolean);
    const isAllowedOrigin = !origin || allowed.includes(origin);

    // CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(origin, isAllowedOrigin) });
    }

    // Block browser requests from unknown origins (server-to-server has no Origin)
    if (origin && !isAllowedOrigin) {
      return new Response("Forbidden origin", { status: 403 });
    }

    // Per-IP rate limiting (best-effort via KV)
    const ip = request.headers.get("CF-Connecting-IP") || "unknown";
    const limited = await isRateLimited(env, ip);
    if (limited) {
      return new Response("Too Many Requests", {
        status: 429,
        headers: { "Retry-After": env.RATE_LIMIT_WINDOW || "60", ...corsHeaders(origin, isAllowedOrigin) },
      });
    }

    // Rewrite to the real Supabase origin, preserving path + query
    const url = new URL(request.url);
    const target = new URL(url.pathname + url.search, SCHEME + env.SUPABASE_HOST);

    const proxied = new Request(target.toString(), request);
    proxied.headers.set("Host", env.SUPABASE_HOST);

    const resp = await fetch(proxied);

    // Re-attach CORS headers on the way back
    const out = new Response(resp.body, resp);
    const cors = corsHeaders(origin, isAllowedOrigin);
    for (const [k, v] of Object.entries(cors)) out.headers.set(k, v);
    return out;
  },
};

function corsHeaders(origin, isAllowedOrigin) {
  return {
    "Access-Control-Allow-Origin": isAllowedOrigin && origin ? origin : "null",
    "Access-Control-Allow-Methods": "GET,POST,PATCH,PUT,DELETE,OPTIONS",
    "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info, prefer, range",
    "Access-Control-Expose-Headers": "content-range, content-length",
    "Access-Control-Allow-Credentials": "true",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
  };
}

async function isRateLimited(env, ip) {
  if (!env.RATE_LIMIT) return false; // KV not bound (e.g. local dev)
  const max = parseInt(env.RATE_LIMIT_MAX || "120", 10);
  const windowSec = parseInt(env.RATE_LIMIT_WINDOW || "60", 10);
  const key = `rl:${ip}`;
  const current = parseInt((await env.RATE_LIMIT.get(key)) || "0", 10);
  if (current >= max) return true;
  await env.RATE_LIMIT.put(key, String(current + 1), { expirationTtl: windowSec });
  return false;
}
