# ZenVX Supabase Proxy (Cloudflare Worker)

This Worker is the **single entry point for all Supabase API traffic**. The Astro
app's Supabase client points at `https://api.zenvx.com` (this Worker) instead of
`https://<project-ref>.supabase.co`, so every REST / Auth / Storage call is
fronted by Cloudflare's DDoS protection, WAF, and rate limiting.

## What it does

- Rewrites incoming requests to the real Supabase origin host
- Enforces an **origin allowlist** (only your frontend domains)
- Handles **CORS** (incl. preflight)
- Applies a simple **per-IP rate limit** via a KV namespace
- Forwards `apikey` and `Authorization` headers untouched

## What it does NOT do

- It does **not** proxy Supabase **Realtime** (WebSocket). The browser connects to
  the Supabase realtime endpoint directly — see `PUBLIC_SUPABASE_REALTIME_URL`.
- It never sees or forwards the `service_role` key.

## Deploy

```bash
cd cloudflare-worker
npm i -g wrangler
wrangler kv namespace create RATE_LIMIT   # paste the id into wrangler.toml
wrangler secret put SUPABASE_HOST         # e.g. your-project-ref.supabase.co
wrangler deploy
```

Then point DNS / route `api.zenvx.com/*` at this Worker (configured in
`wrangler.toml`).
