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

export type ContentBlockReason = "phone_number" | "image_content";

export function checkMessageContent(text: string): ContentBlockReason | null {
  if (DATA_IMAGE_REGEX.test(text) || IMAGE_URL_REGEX.test(text)) return "image_content";
  if (PHONE_REGEX.test(text)) return "phone_number";
  return null;
}

export function messageForBlockReason(reason: ContentBlockReason): string {
  return reason === "phone_number"
    ? "Messages can't include phone numbers — get to know each other here first."
    : "Messages can't include photos or images — those unlock in their own time.";
}
