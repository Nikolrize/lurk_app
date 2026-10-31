
begin;

alter policy "Players upload their own verification images"
on storage.objects
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

commit;
