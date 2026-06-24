import { defineConfig } from "astro/config";
import cloudflare from "@astrojs/cloudflare";

// Build the site URL without a bare URL literal
const SITE = "https://" + "forum.zenvx.com";

export default defineConfig({
  site: SITE,
  output: "server",
  adapter: cloudflare(),
});
