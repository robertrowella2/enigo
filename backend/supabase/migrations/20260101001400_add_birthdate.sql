-- Add birthdate column to profiles table for age verification (18+ requirement).
alter table profiles add column birthdate date;

-- Add constraint to ensure users are 18+.
-- We don't enforce this at the database level (dates can change if corrected),
-- but it's useful for queries. The app enforces the 18+ check at signup.
