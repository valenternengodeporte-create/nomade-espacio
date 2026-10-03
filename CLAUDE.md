# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

"Nómade con Sentido" — a private client space for a professional (Valentina) who accompanies people emigrating, mostly from Argentina to Brazil. Clients log in (invite-only), take a 12-question pre-session test, follow a personalized roadmap ("Tu plan"), read content (experiences, testimonials) and use a safety kit for their destination. The professional (admin) manages content, reviews tests, keeps private session notes, publishes roadmaps and curates safety zones. All UI copy is in Spanish (Rioplatense, `es-AR` date formatting): keep new text in that voice, without long dashes (—) and without "No es X, es Y" formulas.

Valentina is not a programmer: explain things in plain Spanish and ask one decision at a time. Never change production Supabase (tables, policies, data) without showing her the exact SQL first and getting her OK; she runs it herself in the SQL Editor.

## Stack & running

- **No build step, no package manager, no tests.** The whole app is a single `index.html` (~2,100 lines: inline CSS + vanilla JS) that loads `@supabase/supabase-js@2` from jsDelivr (unpinned).
- To run locally, serve the folder with any static server (e.g. `npx serve .`) or open `index.html` directly. It talks to the live Supabase project configured at the top of the main `<script>` block (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, the publishable key, safe to be client-side). The `service_role` key must never be in the repo.
- Published on GitHub Pages (`https://valenternengodeporte-create.github.io/nomade-espacio/`), so every push to `main` goes live. The repo was once linked to Netlify (`.netlify/`, gitignored); a move to Vercel or Netlify is planned.
- Don't commit backups (CSV exports contain clinical data) or audit documents such as `prompt-valentina-nomade.md`.

## Architecture of `index.html`

- **State + full re-render:** a global `state` object (`screen`, `session`, `profile`, `tab`, `hasTest`). `render()` wipes `#app` and calls the `render<Screen>()` function for `state.screen` (`loading` → `login` / `resetPassword` / `nameCapture` → `welcome` → `dashboard`). Render functions build DOM via the `el(html)` helper from template strings and may attach a `node._after` callback that runs once the node is mounted.
- **Auth flow:** `init()` checks the Supabase session; `loadUserAndRoute()` loads `profiles`, checks for an existing test, and routes. `sb.auth.onAuthStateChange` handles `SIGNED_OUT` and `PASSWORD_RECOVERY`.
- **Dashboard tabs:** `renderDashboard()` defines the tab list; `paintTab()` dispatches on `state.tab` (`test` until submitted, `plan`, `experiencia`, `testimonios`, `seguridad`, `admin`). The admin tab only appears when `profiles.is_admin` is true, and `renderAdmin()` has its own sub-tabs (content, tests, clients → per-client detail with notes + roadmap, safety zones).
- **Tu plan:** `renderClientPlan()` shows published `client_feedback` as a roadmap (`renderRoute()`): admin items grouped by `ROUTE_CATS` and `ROUTE_WHEN` (antes / al llegar / primer mes), plus the client's own `client_tasks`; checked items go to `plan_progress`. Old text-only plans render via `renderLegacyPlan()`.
- **Safety kit:** `renderSafety()` combines hardcoded `SAFETY_MISSIONS` (Brazil emergency numbers, scams, quizzes) tracked in `safety_progress`, with the client's assigned zone (`client_safety` → `safety_zones`, curated by the admin in `renderAdminSafety()`). Clients ask for new zones via `zone_requests`.
- **Test:** `QUESTIONS` (12 items, grouped into sub-scales A/B/C in `SUB_LABEL`) and `scoreSubmission()` compute results; submissions go to `test_submissions` (one per user).
- Keyboard shortcuts for a screen are registered via `setKeys(fn)`, which removes the previous handler — always go through it rather than adding raw `keydown` listeners.
- Shared UI helpers: `toast()`, `showErr()`, `skeleton()`, `fmtDate()`, `ytEmbed()`, `ICON`, `sunrise()` (brand SVG). Design tokens are CSS variables in `:root` (amber/teal on a dark background).

## Supabase data model

Tables used by the app: `profiles` (with `name`, `email`, `is_admin`), `test_submissions`, `resources` (category `experiencia` | `testimonio`, type `texto` | `video` | `imagen`), `session_notes`, `client_feedback`, `client_tasks`, `plan_progress`, `client_safety`, `safety_progress`, `safety_zones`, `zone_requests`. The base schema and policies for `profiles`, `test_submissions` and `resources` are not in the repo (created by hand in the dashboard).

`supabase/*.sql` are numbered, idempotent migrations run manually in the Supabase SQL Editor (no CLI/migration tooling). Follow the same pattern for new ones: `create ... if not exists`, `drop policy if exists` before `create policy`, a Spanish header comment explaining purpose and prerequisites.

Security is enforced by RLS, not by the client:
- `session_notes` = private clinical notes, admin-only. `client_feedback` = what the client sees, readable by the client only when `published = true`. They are **separate tables on purpose** — RLS is per row, not per column, so never merge private and client-visible fields into one table.
- `public.nc_is_admin()` (security definer) is the admin check used in policies to avoid recursion on `profiles`; reuse it in new policies.
- `05_proteger_admin.sql`: clients may update only `profiles.name` (column-level grant). The RLS update policy only checks row ownership, so without this a client could set `is_admin = true` and read everyone's notes. If the app ever needs clients to edit another `profiles` column, grant that column explicitly; never re-grant table-wide update.
- Public sign-ups are disabled in Supabase Auth; accounts come only from invitations.
