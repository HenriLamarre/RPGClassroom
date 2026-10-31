-- Checks the security rules and poll math. Run with scripts/test-db.sh.
\set ON_ERROR_STOP 1
insert into auth.users (id, email) values
 ('00000000-0000-0000-0000-00000000000a','prof@cegep.qc.ca'),
 ('00000000-0000-0000-0000-00000000000b','ana@cegep.qc.ca'),
 ('00000000-0000-0000-0000-00000000000c','ben@cegep.qc.ca'),
 ('00000000-0000-0000-0000-00000000000d','eve@gmail.com');
create function as_user(u text) returns void language sql security definer as $$
  select set_config('request.jwt.claims', json_build_object('sub', u, 'email', (select email from auth.users where id = u::uuid))::text, false) $$;
grant execute on function as_user to authenticated;
set role authenticated;

-- teacher creates a semester (roster mode) and adds a roster
select as_user('00000000-0000-0000-0000-00000000000a');
insert into semesters (id, name, join_code) values ('11111111-1111-1111-1111-111111111111','Physique 101','abc');
insert into roster values ('11111111-1111-1111-1111-111111111111','ana@cegep.qc.ca','Ana R'),('11111111-1111-1111-1111-111111111111','ben@cegep.qc.ca',null);

-- students join; eve is not on the roster
select as_user('00000000-0000-0000-0000-00000000000b'); select join_semester('abc');
select as_user('00000000-0000-0000-0000-00000000000c'); select join_semester('abc');
select as_user('00000000-0000-0000-0000-00000000000d');
do $$ begin perform join_semester('abc'); raise exception 'eve should be refused'; exception when others then if sqlerrm = 'eve should be refused' then raise; end if; end $$;
do $$ begin if (select count(*) from semesters) <> 0 then raise exception 'eve sees semester'; end if; end $$;

-- student can't make themselves teacher
select as_user('00000000-0000-0000-0000-00000000000b');
do $$ begin update members set role='teacher' where user_id = auth.uid(); raise exception 'role change allowed'; exception when insufficient_privilege then null; end $$;
update members set show_real_name = true where user_id = auth.uid();
do $$ begin if (select count(*) from members) <> 1 then raise exception 'student sees other members'; end if; end $$;

-- teacher: quest + grade import result + badge
select as_user('00000000-0000-0000-0000-00000000000a');
insert into quests (id, semester_id, title, xp_value, status) values ('22222222-2222-2222-2222-222222222222','11111111-1111-1111-1111-111111111111','Devoir 1',100,'assigned');
insert into quest_completions (quest_id, user_id) values ('22222222-2222-2222-2222-222222222222','00000000-0000-0000-0000-00000000000b'),('22222222-2222-2222-2222-222222222222','00000000-0000-0000-0000-00000000000c');
insert into badges (id, semester_id, name, xp_value, rule_type) values ('33333333-3333-3333-3333-333333333333','11111111-1111-1111-1111-111111111111','90%+',50,'grade_at_least');
insert into badge_awards values ('33333333-3333-3333-3333-333333333333','00000000-0000-0000-0000-00000000000b');

-- student can't award themselves a badge
select as_user('00000000-0000-0000-0000-00000000000c');
do $$ begin insert into badge_awards values ('33333333-3333-3333-3333-333333333333','00000000-0000-0000-0000-00000000000c'); raise exception 'self award allowed'; exception when insufficient_privilege then null; end $$;
do $$ begin perform member_xp('11111111-1111-1111-1111-111111111111','00000000-0000-0000-0000-00000000000b'); raise exception 'member_xp callable'; exception when insufficient_privilege then null; end $$;

-- poll: base 10, max 50
select as_user('00000000-0000-0000-0000-00000000000a');
insert into polls (id, semester_id, question, options, base_amount, max_bet) values ('44444444-4444-4444-4444-444444444444','11111111-1111-1111-1111-111111111111','Vrai ou faux?','{Vrai,Faux}',10,50);
select as_user('00000000-0000-0000-0000-00000000000b');
do $$ begin perform cast_vote('44444444-4444-4444-4444-444444444444',0,11); raise exception 'overbet allowed'; exception when others then if sqlerrm <> 'not enough currency' then raise; end if; end $$;
select cast_vote('44444444-4444-4444-4444-444444444444',0,10);
select as_user('00000000-0000-0000-0000-00000000000c'); select cast_vote('44444444-4444-4444-4444-444444444444',1,5);
do $$ begin perform resolve_poll('44444444-4444-4444-4444-444444444444',0); raise exception 'student resolved'; exception when others then if sqlerrm <> 'not allowed' then raise; end if; end $$;
select as_user('00000000-0000-0000-0000-00000000000a'); select resolve_poll('44444444-4444-4444-4444-444444444444',0);

-- ana: xp 150, currency 10+15-10 = 15 ; ben: xp 100, currency 10+0-5 = 5
select as_user('00000000-0000-0000-0000-00000000000b');
do $$ declare r record; begin select * into r from my_stats('11111111-1111-1111-1111-111111111111');
  if r.xp <> 150 or r.currency <> 15 then raise exception 'ana stats %', r; end if; end $$;
select as_user('00000000-0000-0000-0000-00000000000c');
do $$ declare r record; begin select * into r from my_stats('11111111-1111-1111-1111-111111111111');
  if r.xp <> 100 or r.currency <> 5 then raise exception 'ben stats %', r; end if; end $$;
select * from leaderboard('11111111-1111-1111-1111-111111111111');
select 'ALL TESTS PASSED';
