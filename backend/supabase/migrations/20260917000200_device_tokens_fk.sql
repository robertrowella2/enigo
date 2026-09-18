-- device_tokens referenced profiles(id). A profile only exists once
-- onboarding completes, but the APNs token arrives the instant
-- registerForRemoteNotifications() is called — which the onboarding
-- permission screen does a step *before* the profile is written. So the
-- very first register-device-token call from every new user failed the
-- foreign key, the client swallowed the error, and nothing ever retried.
-- Production had zero device tokens: no user has ever received a push.
--
-- Reference auth.users instead. A signed-in user is all a token needs to
-- belong to; whether they have finished onboarding is irrelevant. Cascade
-- still clears tokens when the account is deleted (delete-account removes
-- the auth user, which is what removed the profile before).
alter table device_tokens drop constraint device_tokens_user_id_fkey;
alter table device_tokens
  add constraint device_tokens_user_id_fkey
  foreign key (user_id) references auth.users (id) on delete cascade;
