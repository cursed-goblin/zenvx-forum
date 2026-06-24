import MarkdownIt from "markdown-it";
import DOMPurify from "isomorphic-dompurify";

const md = new MarkdownIt({ html: false, linkify: true, breaks: true });

// Render user markdown to sanitized HTML. html:false + DOMPurify prevents stored XSS.
export function renderMarkdown(src: string): string {
  return DOMPurify.sanitize(md.render(src ?? ""));
}

// Plain-text excerpt for meta descriptions
export function excerpt(src: string, len = 160): string {
  return (src ?? "").replace(/[#*`>_\[\]()!-]/g, "").replace(/\s+/g, " ").trim().slice(0, len);
}
