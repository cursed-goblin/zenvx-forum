# ZenVX Community Forum

A community forum for **ZenVX**, built on:

- **Astro** (SSR via `@astrojs/cloudflare`) for an SEO-friendly frontend
- **Supabase** for Postgres, Auth, and Realtime
- **Cloudflare Pages** for hosting + **Cloudflare Workers** as an API proxy

## ⚠️ Hard requirement: proxy ALL Supabase API calls through Cloudflare

Every Supabase REST / Auth / Storage call **must** route through the Cloudflare
Worker proxy (`api.zenvx.com`) instead of hitting `*.supabase.co` directly. This
hides the origin project URL and puts Cloudflare's DDoS protection + rate limiting
in front of the database. The Supabase client is configured with the proxy URL as
its `supabaseUrl`. See [`cloudflare-worker/`](./cloudflare-worker) and
[`src/lib/supabase.ts`](./src/lib/supabase.ts).

> Note: Supabase **Realtime** is a WebSocket and is handled separately (see the
> worker README) — it does not flow through the HTTP proxy.

## Project structure

```
supabase/         # SQL migrations + seed (schema, RLS, triggers)
cloudflare-worker/# API proxy Worker (wrangler project)
src/              # Astro app (pages, components, lib)
```

## Build steps

1. Database schema + RLS — `supabase/migrations`
2. Auth strategy — email/password + Google OAuth, public read / authed write
3. Security — RLS + Cloudflare Worker proxy
4. Frontend — thread list, thread detail + replies, post form, markdown
5. Realtime — live reply updates
6. Moderation — reports, soft-delete, admin role
7. SEO — SSR meta tags, sitemap, JSON-LD
8. Deployment — Cloudflare Pages + Worker

See the full project plan in Notion.
