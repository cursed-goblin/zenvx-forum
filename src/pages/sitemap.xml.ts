import type { APIRoute } from "astro";
import { supabase } from "../lib/supabase";

const NS = "http://" + "www.sitemaps.org/schemas/sitemap/0.9";

export const GET: APIRoute = async ({ site }) => {
  const base = (site?.toString() ?? "").replace(/\/$/, "");
  const { data: threads } = await supabase
    .from("threads")
    .select("slug, updated_at, categories(slug)")
    .eq("is_deleted", false);

  const urls = (threads ?? [])
    .map((t) => {
      const loc = `${base}/c/${t.categories?.slug}/${t.slug}`;
      const lastmod = new Date(t.updated_at).toISOString();
      return `<url><loc>${loc}</loc><lastmod>${lastmod}</lastmod></url>`;
    })
    .join("");

  const xml = `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="${NS}">${urls}</urlset>`;
  return new Response(xml, { headers: { "Content-Type": "application/xml" } });
};
