import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

async function sendFeedbackEmail(params: {
  message: string;
  userId: string;
}): Promise<void> {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  const to = Deno.env.get("REPORT_ALERT_EMAIL");
  if (!apiKey || !to) return;
  try {
    await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "Enigo Feedback <onboarding@resend.dev>",
        to,
        subject: "New Enigo user feedback",
        text: [
          `User: ${params.userId}`,
          `Message: ${params.message}`,
        ].join("\n"),
      }),
    });
  } catch (_error) {
    // Swallow email errors
  }
}

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    const callerId = ctx.userClaims!.id;
    const admin = ctx.supabaseAdmin;
    const { message } = await req.json();

    if (!message || message.trim().length === 0) {
      return Response.json({ message: "Message cannot be empty", code: "invalid_body" }, { status: 400 });
    }

    const { error: feedbackError } = await admin.from("feedback").insert({
      user_id: callerId,
      message: message.trim(),
    });
    if (feedbackError) throw feedbackError;

    await sendFeedbackEmail({
      message: message.trim(),
      userId: callerId,
    });

    return Response.json({ ok: true });
  }),
};
