begin;

create policy "Players upload their own verification images"
on storage.objects
for insert
to anon, authenticated
with check (
  bucket_id = 'identity-verification'

  and (auth.jwt() ->> 'iss')
    = 'https://securetoken.google.com/lurk-mae'

  and (auth.jwt() ->> 'aud') = 'lurk-mae'

  and nullif(auth.jwt() ->> 'sub', '') is not null

  and array_length(storage.foldername(name), 1) = 2

  and (storage.foldername(name))[1]
    = (auth.jwt() ->> 'sub')

  and (storage.foldername(name))[2]
    ~ '^[a-f0-9-]{36}$'

  and storage.filename(name)
    ~ '^id[.](jpg|png|webp)$'
);

-- Only the owner or an authorized admin can view verification images.
create policy "Owners and admins view verification images"
on storage.objects
for select
to anon, authenticated
using (
  bucket_id = 'identity-verification'

  and (auth.jwt() ->> 'iss')
    = 'https://securetoken.google.com/lurk-mae'

  and (auth.jwt() ->> 'aud') = 'lurk-mae'

  and nullif(auth.jwt() ->> 'sub', '') is not null

  and (
    (storage.foldername(name))[1]
      = (auth.jwt() ->> 'sub')

    or (select public.is_identity_verification_admin())
  )
);

commit;
