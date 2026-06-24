# ZenVX Supabase Proxy (Cloudflare Worker)

This Worker is the **single entry point for all Supabase traffic**. The Astro
app's Supabase client points at `https://api.zenvx.com` (this Worker) instead of
`https://<project-ref>.supabase.co`, so every REST / Auth / Storage call **and the
Realtime WebSocket** are fronted by Cloudflare's DDoS protection and rate limiting.

## What it does

- Rewrites incoming HTTP requests to the real Supabase origin host
- **Proxies the Realtime WebSocket** via the `Upgrade: websocket` passthrough
- Enforces an **origin allowlist** (only your frontend domains)
- Handles **CORS** (incl. preflight)
- Applies a simple **per-IP rate limit** via a KV namespace
- Forwards `apikey` and `Authorization` headers untouched

## What it never does

- It never sees or forwards the `service_role` key.

## Deploy

```bash
cd cloudflare-worker
npm i -g wrangler
wrangler kv namespace create RATE_LIMIT   # paste the id into wrangler.toml
wrangler secret put SUPABASE_HOST         # e.g. your-project-ref.supabase.co
wrangler deploy
```

Then route `api.zenvx.com/*` at this Worker (configured in `wrangler.toml`).
Because Supabase Realtime is now proxied here too, the browser only ever talks
to `api.zenvx.com` — the origin Supabase URL is never exposed to clients.
