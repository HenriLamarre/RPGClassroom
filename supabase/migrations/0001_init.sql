-- RPGClassroom initial schema.
-- Run once in your Supabase project (SQL Editor > paste > Run), or with `supabase db push`.
-- Every table has Row Level Security on. Writes that need checks go through functions below.
-- Grades are never stored: the grade import runs in the teacher's browser and only writes
-- the resulting quest completions and badge awards.

-- ---------- Semesters and membership ----------

create table semesters (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users on delete cascade,
  name text not null,
  language text not null default 'fr' check (language in ('fr', 'en')),
  currency_name text not null default 'Écus',
  currency_icon text not null default '🪙',
  leaderboard_enabled boolean not null default true,
  leaderboard_size int not null default 10 check (leaderboard_size between 1 and 100),
  join_mode text not null default 'roster' check (join_mode in ('roster', 'open')),
  allowed_email_domain text,           -- open mode only, e.g. 'moncegep.qc.ca'
  join_code text not null unique default encode(gen_random_bytes(6), 'hex'),  -- in the QR code
  poll_base_amount int not null default 10 check (poll_base_amount >= 0),
  poll_max_bet int not null default 50 check (poll_max_bet >= 0),
  created_at timestamptz not null default now()
);

create table members (
  semester_id uuid not null references semesters on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  role text not null check (role in ('teacher', 'student')),
  email text not null,
  real_name text,
  username text not null,              -- generic name shown on the leaderboard by default
  show_real_name boolean not null default false,
  language text check (language in ('fr', 'en')),  -- null = use the semester's language
  bio text,
  avatar_url text,
  joined_at timestamptz not null default now(),
  primary key (semester_id, user_id)
);

-- Roster mode: only these emails can join.
create table roster (
  semester_id uuid not null references semesters on delete cascade,
  email text not null,
  real_name text,
  primary key (semester_id, email)
);

-- security definer so policies can call these without recursing into members' own policies.
create function is_member(s uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from members where semester_id = s and user_id = auth.uid())
$$;

create function is_teacher(s uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from members where semester_id = s and user_id = auth.uid() and role = 'teacher')
$$;

-- The creator of a semester becomes its teacher.
create function add_owner_as_teacher() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into members (semester_id, user_id, role, email, username)
  values (new.id, new.owner_id, 'teacher', coalesce(auth.jwt() ->> 'email', ''), 'Maître du jeu');
  return new;
end $$;

create trigger semesters_add_owner after insert on semesters
for each row execute function add_owner_as_teacher();

-- Students join with the code from the QR code.
create function join_semester(code text) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  s semesters;
  user_email text := lower(auth.jwt() ->> 'email');
  n int;
begin
  if auth.uid() is null or user_email is null then raise exception 'not signed in'; end if;
  select * into s from semesters where join_code = code;
  if not found then raise exception 'unknown join code'; end if;
  if exists (select 1 from members where semester_id = s.id and user_id = auth.uid()) then
    return s.id;
  end if;
  if s.join_mode = 'roster'
     and not exists (select 1 from roster where semester_id = s.id and lower(email) = user_email) then
    raise exception 'email not on the class list';
  end if;
  if s.join_mode = 'open' and s.allowed_email_domain is not null
     and split_part(user_email, '@', 2) <> lower(s.allowed_email_domain) then
    raise exception 'email domain not allowed';
  end if;
  select count(*) into n from members where semester_id = s.id;
  insert into members (semester_id, user_id, role, email, real_name, username)
  values (s.id, auth.uid(), 'student', user_email,
          (select real_name from roster where semester_id = s.id and lower(email) = user_email),
          case when s.language = 'en' then 'Adventurer ' else 'Aventurier ' end || n);
  return s.id;
end $$;

-- ---------- Quests and badges ----------

create table quests (
  id uuid primary key default gen_random_uuid(),
  semester_id uuid not null references semesters on delete cascade,
  title text not null,
  description text,
  category text not null default 'assignment'
    check (category in ('reading', 'assignment', 'quiz', 'project', 'participation', 'bonus')),
  xp_value int not null default 0 check (xp_value >= 0),
  due_date date,
  status text not null default 'draft' check (status in ('draft', 'assigned', 'archived')),
  created_at timestamptz not null default now()
);

create table quest_completions (
  quest_id uuid not null references quests on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  status text not null default 'approved' check (status in ('submitted', 'approved', 'rejected')),
  note text,
  submission_link text,
  reviewed_at timestamptz default now(),
  primary key (quest_id, user_id)
);

create table badges (
  id uuid primary key default gen_random_uuid(),
  semester_id uuid not null references semesters on delete cascade,
  name text not null,
  description text,
  tier text not null default 'bronze' check (tier in ('bronze', 'silver', 'gold', 'legendary')),
  icon text,
  xp_value int not null default 0 check (xp_value >= 0),
  -- How the badge is earned. Params examples:
  --   grade_at_least:  {"quest_id": "...", "min_percent": 90}   (checked during grade import)
  --   category_count:  {"category": "quiz", "count": 3}
  --   polls_won:       {"count": 10}
  --   xp_at_least:     {"xp": 500}
  rule_type text not null default 'manual'
    check (rule_type in ('manual', 'grade_at_least', 'category_count', 'polls_won', 'xp_at_least')),
  rule_params jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create table badge_awards (
  badge_id uuid not null references badges on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  awarded_at timestamptz not null default now(),
  primary key (badge_id, user_id)
);

-- ---------- Live polls (predictions) ----------

create table polls (
  id uuid primary key default gen_random_uuid(),
  semester_id uuid not null references semesters on delete cascade,
  question text not null,
  options text[] not null check (array_length(options, 1) between 2 and 6),
  correct_option int,                  -- index into options, set when resolved
  status text not null default 'open' check (status in ('open', 'closed', 'resolved')),
  base_amount int not null check (base_amount >= 0),
  max_bet int not null check (max_bet >= 0),
  created_at timestamptz not null default now()
);

create table poll_votes (
  poll_id uuid not null references polls on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  option int not null,
  bet int not null default 0 check (bet >= 0),
  payout int,                          -- set when the poll is resolved
  primary key (poll_id, user_id)
);

-- Balance = every poll's base amount + payouts - bets.
create function currency_balance(s uuid, u uuid) returns int
language sql stable security definer set search_path = public as $$
  select coalesce(sum(p.base_amount + coalesce(v.payout, 0) - v.bet), 0)::int
  from poll_votes v join polls p on p.id = v.poll_id
  where p.semester_id = s and v.user_id = u
$$;

create function cast_vote(p_poll uuid, p_option int, p_bet int) returns void
language plpgsql security definer set search_path = public as $$
declare
  p polls;
begin
  select * into p from polls where id = p_poll for update;
  if not found or p.status <> 'open' then raise exception 'poll is not open'; end if;
  if not is_member(p.semester_id) then raise exception 'not in this class'; end if;
  if p_option < 0 or p_option >= array_length(p.options, 1) then raise exception 'bad option'; end if;
  if p_bet < 0 or p_bet > p.max_bet then raise exception 'bet over the maximum'; end if;
  -- The base amount for this poll counts toward what can be bet on it.
  if p_bet > currency_balance(p.semester_id, auth.uid()) + p.base_amount then
    raise exception 'not enough currency';
  end if;
  insert into poll_votes (poll_id, user_id, option, bet) values (p_poll, auth.uid(), p_option, p_bet);
end $$;

-- Winners split the losers' pot in proportion to their bets (rounded down).
-- No losers: everyone keeps their bet. No winners: the pot is lost.
create function resolve_poll(p_poll uuid, p_correct int) returns void
language plpgsql security definer set search_path = public as $$
declare
  p polls;
  pot int;
  winning_bets int;
begin
  select * into p from polls where id = p_poll for update;
  if not found or not is_teacher(p.semester_id) then raise exception 'not allowed'; end if;
  if p.status = 'resolved' then raise exception 'already resolved'; end if;
  if p_correct < 0 or p_correct >= array_length(p.options, 1) then raise exception 'bad option'; end if;
  select coalesce(sum(bet) filter (where option <> p_correct), 0),
         coalesce(sum(bet) filter (where option = p_correct), 0)
    into pot, winning_bets from poll_votes where poll_id = p_poll;
  update poll_votes set payout = case
      when option <> p_correct then 0
      when winning_bets = 0 then bet
      else bet + (bet::bigint * pot / winning_bets)::int
    end
  where poll_id = p_poll;
  update polls set status = 'resolved', correct_option = p_correct where id = p_poll;
end $$;

-- ---------- XP and leaderboard ----------

create function member_xp(s uuid, u uuid) returns int
language sql stable security definer set search_path = public as $$
  select (
    coalesce((select sum(q.xp_value) from quest_completions c join quests q on q.id = c.quest_id
              where q.semester_id = s and c.user_id = u and c.status = 'approved'), 0)
  + coalesce((select sum(b.xp_value) from badge_awards a join badges b on b.id = a.badge_id
              where b.semester_id = s and a.user_id = u), 0)
  )::int
$$;

-- Top N students, under their generic username unless they opted in to their real name.
create function leaderboard(s uuid)
returns table (display_name text, xp int, is_me boolean)
language sql stable security definer set search_path = public as $$
  select case when m.show_real_name and m.real_name is not null then m.real_name else m.username end,
         member_xp(s, m.user_id),
         m.user_id = auth.uid()
  from members m join semesters sem on sem.id = m.semester_id
  where m.semester_id = s and m.role = 'student' and sem.leaderboard_enabled and is_member(s)
  order by 2 desc
  limit (select leaderboard_size from semesters where id = s)
$$;

-- Your own XP and currency, for the character sheet.
create function my_stats(s uuid) returns table (xp int, currency int)
language sql stable security definer set search_path = public as $$
  select member_xp(s, auth.uid()), currency_balance(s, auth.uid()) where is_member(s)
$$;

-- These take any user id, so only the functions above may call them.
revoke execute on function member_xp(uuid, uuid), currency_balance(uuid, uuid) from public, anon, authenticated;

-- ---------- Row Level Security ----------

alter table semesters enable row level security;
alter table members enable row level security;
alter table roster enable row level security;
alter table quests enable row level security;
alter table quest_completions enable row level security;
alter table badges enable row level security;
alter table badge_awards enable row level security;
alter table polls enable row level security;
alter table poll_votes enable row level security;

create policy "members read" on semesters for select using (is_member(id));
create policy "anyone signed in creates" on semesters for insert to authenticated
  with check (owner_id = auth.uid());
create policy "teacher updates" on semesters for update using (is_teacher(id));
create policy "owner deletes" on semesters for delete using (owner_id = auth.uid());

create policy "self or teacher reads" on members for select
  using (user_id = auth.uid() or is_teacher(semester_id));
create policy "self or teacher updates" on members for update
  using (user_id = auth.uid() or is_teacher(semester_id));
create policy "teacher removes" on members for delete using (is_teacher(semester_id));
-- Students may only change their own profile settings, never role or email.
revoke update on members from authenticated, anon;
grant update (show_real_name, language, bio, avatar_url, real_name) on members to authenticated;

create policy "teacher only" on roster for all
  using (is_teacher(semester_id)) with check (is_teacher(semester_id));

create policy "members read" on quests for select
  using (is_teacher(semester_id) or (is_member(semester_id) and status <> 'draft'));
create policy "teacher writes" on quests for all
  using (is_teacher(semester_id)) with check (is_teacher(semester_id));

create policy "self or teacher reads" on quest_completions for select using (
  user_id = auth.uid() or is_teacher((select semester_id from quests where id = quest_id)));
create policy "teacher writes" on quest_completions for all
  using (is_teacher((select semester_id from quests where id = quest_id)))
  with check (is_teacher((select semester_id from quests where id = quest_id)));

create policy "members read" on badges for select using (is_member(semester_id));
create policy "teacher writes" on badges for all
  using (is_teacher(semester_id)) with check (is_teacher(semester_id));

create policy "self or teacher reads" on badge_awards for select using (
  user_id = auth.uid() or is_teacher((select semester_id from badges where id = badge_id)));
create policy "teacher writes" on badge_awards for all
  using (is_teacher((select semester_id from badges where id = badge_id)))
  with check (is_teacher((select semester_id from badges where id = badge_id)));

create policy "members read" on polls for select using (is_member(semester_id));
create policy "teacher writes" on polls for all
  using (is_teacher(semester_id)) with check (is_teacher(semester_id));

-- Votes are written only through cast_vote / resolve_poll.
create policy "self or teacher reads" on poll_votes for select using (
  user_id = auth.uid() or is_teacher((select semester_id from polls where id = poll_id)));

-- Live poll updates for the classroom screen.
alter publication supabase_realtime add table polls, poll_votes;
