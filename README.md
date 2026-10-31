# RPG Classroom

Une application web libre pour suivre une session au cégep comme un jeu de rôle : fiches de personnage,
points d'expérience, badges et sondages en direct avec prédictions.

*An open-source web app to run a college semester like an RPG: character sheets, XP, badges and
live prediction polls. French and English.*

> Early stage: this is the project skeleton (database, security rules, sign-in). Features come next.
> Design decisions are in [CLAUDE.md](CLAUDE.md).

## Deploy your own copy (free)

You need a GitHub account and a free [Supabase](https://supabase.com) account. No server to run.

1. **Fork** this repository on GitHub.
2. **Create a Supabase project.** Pick the **Canada (Central)** region so student data stays in
   Canada (Quebec Law 25).
3. **Create the database.** In Supabase, open *SQL Editor*, paste the content of
   [`supabase/migrations/0001_init.sql`](supabase/migrations/0001_init.sql) and click *Run*.
4. **Set the sign-in redirect.** In Supabase, *Authentication > URL Configuration*, set the Site URL
   to your site's address: `https://<your-github-name>.github.io/<repo-name>/`.
5. **Connect the site to Supabase.** In your fork on GitHub, go to *Settings > Secrets and variables >
   Actions > Variables* and add two variables, from Supabase's *Project Settings > API*:
   - `VITE_SUPABASE_URL`: the project URL
   - `VITE_SUPABASE_ANON_KEY`: the anon (public) key. It's safe to publish; the database's
     security rules protect the data.
6. **Turn on GitHub Pages.** In *Settings > Pages*, set *Source* to *GitHub Actions*. Then in the
   *Actions* tab, run *Deploy to GitHub Pages*. Your site is live at the address from step 4.

Supabase's free plan pauses a project after a week without activity; open the site or the
Supabase dashboard to wake it up.

## Develop locally

```sh
cp .env.example .env   # fill in your Supabase URL and key
npm install
npm run dev
```

Test the database rules (needs a local Postgres): `PSQL="psql -U postgres" scripts/test-db.sh`

## License

To be decided.
