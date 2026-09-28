import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY")!;

serve(async (req) => {
  try {
    const { record, old_record } = await req.json();

    const newStatus = record.status;
    const oldStatus = old_record?.status;

    // ⚠️ تەنها کاتێک status دەگۆڕدرێت
    if (newStatus === oldStatus) {
      return new Response(JSON.stringify({ skipped: true }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // 📢 تەنها بۆ ئەم دۆخانە Notification بنێرە
    const notifyStatuses = ["in_progress", "approved", "completed", "rejected"];
    if (!notifyStatuses.includes(newStatus)) {
      return new Response(JSON.stringify({ skipped: "status not in list" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // 📥 وەرگرتنی FCM Token ی بەکارهێنەر
    const { data: user } = await supabase
      .from("app_users")
      .select("fcm_token, name")
      .eq("id", record.user_id)
      .maybeSingle();

    if (!user?.fcm_token) {
      return new Response(JSON.stringify({ error: "No FCM token" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // 🎨 تایتڵ و دەق بەپێی status
    let title = "";
    let body = "";

    switch (newStatus) {
      case "in_progress":
      case "approved":
        title = "✅ سکاڵاکەت پەسەندکرا";
        body = `سکاڵای "${record.title}" پەسەندکرا و لە ئارادایە.`;
        break;
      case "completed":
        title = "🎉 سکاڵاکەت جێبەجێکرا";
        body = `سکاڵای "${record.title}" بە سەرکەوتوویی جێبەجێکرا. سوپاس بۆ هاوکاریت!`;
        break;
      case "rejected":
        title = "❌ سکاڵاکەت ڕەتکرایەوە";
        body = `بەداخەوە سکاڵای "${record.title}" ڕەتکرایەوە.`;
        break;
    }

    // 🔔 ناردنی Notification بە FCM
    const fcmResponse = await fetch(
      "https://fcm.googleapis.com/fcm/send",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `key=${FCM_SERVER_KEY}`,
        },
        body: JSON.stringify({
          to: user.fcm_token,
          notification: {
            title: title,
            body: body,
            sound: "default",
          },
          data: {
            route: "/complaints",
            complaint_id: record.id.toString(),
            status: newStatus,
          },
        }),
      }
    );

    const fcmResult = await fcmResponse.json();

    return new Response(
      JSON.stringify({ success: true, fcm: fcmResult }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});