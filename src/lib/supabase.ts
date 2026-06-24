import { createClient } from "@supabase/supabase-js";

// IMPORTANT: supabaseUrl is the Cloudflare proxy (e.g. https://api.zenvx.com),
// NOT the raw *.supabase.co URL. This forces ALL traffic — REST, Auth, Storage,
// and the Realtime WebSocket — through Cloudflare for DDoS protection.
// supabase-js derives the realtime endpoint from this URL, so the WS connection
// becomes wss://api.zenvx.com/realtime/v1, which the Worker proxies to Supabase.
const proxyUrl = import.meta.env.PUBLIC_SUPABASE_PROXY_URL;
const anonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

export const supabase = createClient(proxyUrl, anonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});
