create policy "Players manage their own profile images"
on storage.objects
for all
to anon, authenticated
using (
  bucket_id = 'profile-images'

  and (auth.jwt() ->> 'iss')
    = 'https://securetoken.google.com/lurk-mae'

  and (auth.jwt() ->> 'aud') = 'lurk-mae'

  and nullif(auth.jwt() ->> 'sub', '') is not null

  and (storage.foldername(name))[1]
    = (auth.jwt() ->> 'sub')
)
with check (
  bucket_id = 'profile-images'

  and (auth.jwt() ->> 'iss')
    = 'https://securetoken.google.com/lurk-mae'

  and (auth.jwt() ->> 'aud') = 'lurk-mae'

  and nullif(auth.jwt() ->> 'sub', '') is not null

  and (storage.foldername(name))[1]
    = (auth.jwt() ->> 'sub')
);