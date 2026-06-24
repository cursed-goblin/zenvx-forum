-- Sample categories for local/dev seeding
insert into public.categories (name, slug, description, sort_order) values
  ('Announcements', 'announcements', 'Official ZenVX news and updates', 0),
  ('General', 'general', 'General discussion about ZenVX', 1),
  ('Help & Support', 'help', 'Questions and troubleshooting', 2),
  ('Development', 'development', 'Kernel, subsystems, and contributions', 3),
  ('Feature Requests', 'feature-requests', 'Ideas and proposals', 4)
on conflict (slug) do nothing;
