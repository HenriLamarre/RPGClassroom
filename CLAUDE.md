# RPGClassroom

Open-source web app for Quebec Cegep classes: the teacher and students track a semester as an RPG.
Each student has a character sheet, XP, levels/ranks and badges, and the class has live polls.

## Decisions (2026-10-31)

- **Stack:** static frontend (deployable on GitHub Pages) + **Supabase** for Postgres, auth, storage
  and Realtime (live polls). No server of our own.
- **Self-hosting:** each teacher deploys their own copy with their own free Supabase project.
  Setup should be "create a Supabase project, paste two keys". Use the Canada region (Law 25).
- **Softr:** Henri's Softr app "Medieval RPG Student Portal" is only the mockup/spec, not the product.
- **No LMS integration in v1** (Omnivox/LÉA has no public API). A CSV roster import is enough.

## Data model (ported from the Softr prototype)

- `users`: name, avatar, role (`instructor` | `student`)
- `quests`: title, description, status (draft/assigned/completed/archived), xp_value, due_date,
  category (reading/assignment/quiz/project/participation), badge tier, assigned_by
- `quest_completions`: quest, student, status (not started/in progress/submitted/approved/rejected),
  notes, submission link, awarded_xp, awarded_badge, reviewed_by, submitted_at, reviewed_at
- `badges`: name, description, tier (bronze/silver/gold/legendary), icon
- `badge_awards`: student, badge, awarded_at
- Character sheet: bio, avatar, plus total XP, level and rank (novice → legend).
  **Compute these from approved completions** (view or SQL function), never store them by hand.
- New: `polls`, `poll_options`, `poll_votes`, with Supabase Realtime for live results.

## Principles

- Privacy first (Quebec Law 25): collect the minimum student data, prefer pseudonyms/class codes,
  and enforce access with Supabase Row Level Security on every table.
- XP stays separate from the official grade (it's formative).

## Open questions

- Who gives out XP: the teacher by hand, automatic rules (polls, attendance), or both?
- Can students see each other's sheets, or a leaderboard?
- UI language: French, English, or both?
- Login: class code + pseudonym vs Microsoft 365 / Google.
