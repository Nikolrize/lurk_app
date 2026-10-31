begin;

create schema if not exists verification_private;

create table if not exists verification_private.admins (
  firebase_uid text primary key,
  enabled boolean not null default true
);

alter table verification_private.admins
  enable row level security;

revoke all on schema verification_private
  from public, anon, authenticated;

revoke all on table verification_private.admins
  from public, anon, authenticated;

insert into verification_private.admins (
  firebase_uid,
  enabled
)
values (
  'dSgfQ7E19FTOT4OwAAWjVqk72nB3',
  true
)
on conflict (firebase_uid)
do update set enabled = excluded.enabled;

create or replace function public.is_identity_verification_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (auth.jwt() ->> 'iss')
      = 'https://securetoken.google.com/lurk-mae'

    and (auth.jwt() ->> 'aud') = 'lurk-mae'

    and exists (
      select 1
      from verification_private.admins as admin
      where admin.firebase_uid = (auth.jwt() ->> 'sub')
        and admin.enabled = true
    ),
    false
  );
$$;

revoke all
  on function public.is_identity_verification_admin()
  from public;

grant execute
  on function public.is_identity_verification_admin()
  to anon, authenticated;

commit;
