-- Stores the optional reason chip a user picks on the "This isn't quite
-- it" screen. Separate from end_reason (which is the fixed enum describing
-- how a match ended) since this is free-form product-analytics data about
-- *why*, not a system-level classification.
alter table matches add column soft_exit_reason text;
