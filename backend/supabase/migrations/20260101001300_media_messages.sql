-- Add support for GIF and photo messages, with photo access gated behind graduation (unlock).
alter table messages add column gif_url text, add column photo_url text;

-- Validate that gif_url only contains GIPHY URLs (must start with https://media.giphy.com/ or similar)
-- This is enforced at the application level in send-message, not via constraint.
