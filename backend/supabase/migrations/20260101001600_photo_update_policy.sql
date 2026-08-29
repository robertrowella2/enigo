-- The photos bucket had policies for INSERT and SELECT but none for UPDATE.
-- Backend.uploadPhoto sends upsert: true, so uploading to a path that already
-- holds an object is an UPDATE rather than an INSERT — and with no policy
-- permitting it, storage refused with "new row violates row-level security
-- policy". That is every second photo upload: anyone replacing their photo,
-- or re-running onboarding on an account that already had one.
--
-- Same ownership test as the other two policies: the first path segment must
-- be the caller's own user id. WITH CHECK as well as USING, so a row cannot be
-- moved out of the owner's folder by updating it.
create policy "photos: owner can update own" on storage.objects
  for update using (
    bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text
  ) with check (
    bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text
  );
