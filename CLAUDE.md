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

## XP, quests and badges (decided 2026-10-31)

- XP comes from **approved quest completions** and **badges**.
- Quests are approved by the teacher, made efficient by **grade import**: the teacher uploads a
  CSV (student, grade) for a quest; every student with a grade gets the completion approved,
  students without a grade don't. **Grades are never stored or shown**: they're used during the
  import to award completions and badges, then discarded (students see grades in Omnivox).
  A badge added later is applied by re-uploading the CSV.
- Badges = achievements, awarded **automatically by rule** or **by hand**. Built-in rule types
  (teacher picks one + parameters to make a custom badge), e.g. grade ≥ X on a quest, N quests
  of a category, bonus question earned, polls won. Rules re-run after each grade import.
- Bonus questions on assignments are a main badge source.

## Polls (proposal, Twitch-style predictions)

- Teacher launches a T/F or A/B/C/D question; students vote and bet; when it closes the answer is
  revealed and winners split the losers' pot in proportion to their bets.
- Bets use a **separate class currency**, never XP, so XP and levels only go up. The teacher
  sets the currency's name and icon per semester (avoid gambling words like "gold").
  Call them "predictions" in the UI, not "bets".
- Each poll grants a base amount to every voter; bets are capped by a per-poll maximum.
- Edge cases: no losers → everyone keeps their bet; no winners → pot is lost.

## Visibility (decided 2026-10-31)

- Character sheets are private (student + teacher only).
- Class leaderboard shows only the **top N** (teacher sets N; teacher can turn it off).
- On the leaderboard a student appears under a **generic username** by default
  (e.g. "Aventurier 12"); they opt in on their sheet to show their real name.

## Later (not v1)

- In-app shop spending the currency.
- Teacher can switch features (e.g. the shop) off during class: start with a manual toggle,
  maybe a class schedule later.

## Open questions

- Match imported grades by student name or by student number?
- UI language: French, English, or both?
- Login: class code + pseudonym vs Microsoft 365 / Google.
