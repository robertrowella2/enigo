// Blocks a message that tries to share a phone number or a photo/image —
// both are premature identity/contact reveals that bypass the whole
// slow-unlock mechanic (see design_handoff_enigo/README.md). Enforced here
// because send-message is the one path that can create a `messages` row,
// so this can't be bypassed by any client.

// Matches common phone-number shapes: 5551234567, 555-123-4567,
// 555.123.4567, 555 123 4567, (555) 123-4567, +1 555-123-4567, etc.
const PHONE_REGEX = /(\+?\d{1,2}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b/;

// Image URLs (by extension) and inline base64 image data URIs — the only
// two ways "a photo" could show up in a plain-text message body, since
// there's no image-attachment upload path in chat at all.
const IMAGE_URL_REGEX = /https?:\/\/\S+\.(jpe?g|png|gif|webp|heic|heif|bmp|svg|tiff?)(\?\S*)?/i;
const DATA_IMAGE_REGEX = /data:image\/[a-z0-9.+-]+;base64,/i;

export type ContentBlockReason = "phone_number" | "image_content" | "last_name";

export function checkMessageContent(text: string): ContentBlockReason | null {
  if (DATA_IMAGE_REGEX.test(text) || IMAGE_URL_REGEX.test(text)) return "image_content";
  if (PHONE_REGEX.test(text)) return "phone_number";
  return null;
}

/** Escapes a string for safe use inside a RegExp literal. */
function escapeRegExp(text: string): string {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * True if `text` says the sender's own last name, as a whole word
 * (case-insensitive) — not just a substring, so a short last name like
 * "Lee" doesn't false-positive inside "sleep". First name is deliberately
 * NOT checked here: sharing it is allowed (it's the same thing the
 * show_first_name toggle can already reveal), only the last name is kept
 * out of chat entirely.
 */
export function checkOwnLastNameLeak(text: string, lastName: string | null): boolean {
  const trimmed = lastName?.trim();
  if (!trimmed) return false;
  const pattern = new RegExp(`\\b${escapeRegExp(trimmed)}\\b`, "i");
  return pattern.test(text);
}

/**
 * Returns the digits in `text` if the message reads like a deliberate
 * fragment of a phone number rather than an ordinary sentence that happens
 * to contain a number ("I'm 28", "back in 2024") — a message counts as a
 * fragment when it has at least 2 digits and digits make up most of its
 * non-space content. Used to catch someone splitting a phone number across
 * several messages ("720" / "980" / "1520") to dodge the single-message
 * PHONE_REGEX check above.
 */
function digitFragment(text: string): string | null {
  const digits = text.replace(/\D/g, "");
  if (digits.length < 2) return null;
  const nonSpace = text.replace(/\s/g, "");
  if (nonSpace.length === 0 || digits.length / nonSpace.length < 0.6) return null;
  return digits;
}

/**
 * True if `currentText`, appended to the sender's own recent digit-fragment
 * messages in this match (oldest first, ordinary non-fragment messages in
 * between are ignored rather than breaking the sequence), assembles into
 * something long enough to be a real phone number (7+ digits — covers a
 * bare 7-digit local number up through an 11-digit number with country
 * code). Only ever triggers on a message that is itself a fragment, so a
 * normal sentence is never blocked just because of someone's past history.
 */
export function checkFragmentedPhoneNumber(recentBodiesOldToNew: string[], currentText: string): boolean {
  const current = digitFragment(currentText);
  if (!current) return false;
  const priorDigits = recentBodiesOldToNew
    .map(digitFragment)
    .filter((d): d is string => d !== null)
    .join("");
  return (priorDigits + current).length >= 7;
}

export function messageForBlockReason(reason: ContentBlockReason): string {
  switch (reason) {
    case "phone_number":
      return "Messages can't include phone numbers — get to know each other here first.";
    case "last_name":
      return "Messages can't include your last name — first name only, for now.";
    default:
      return "Messages can't include photos or images — those unlock in their own time.";
  }
}
