// supabase/functions/send-complaint-notification/index.ts
//
// 📣 ئاگاداری push بۆ ئەدمینەکان کاتێک سکاڵایەکی نوێ دێت.
// Database Webhook (Insert لەسەر complaints) ئەم فەنکشنە بانگ دەکات.
// هەر سکاڵایەک تەنها یەکجار دەنێردرێت: complaints.notified_at وەک «قفڵ» بەکاردێت.
// دەنێردرێت بۆ fcm_token ـی هەموو ئەدمینە پەسەندکراوەکان.
import {
  clearTokens, json, loadServiceAccount, recordId, sendFcm, supabaseRest, uniqueTokens,
} from '../_shared/fcm.ts';

const TITLE = '📣 سکاڵای نوێ';

export async function handle(req: Request): Promise<Response> {
  const db = supabaseRest();
  if (!db) return json({ error: 'supabase env missing' }, 500);

  const id = await recordId(req);
  if (id == null) return json({ error: 'complaint id required' }, 400);

  const sa = loadServiceAccount(Deno.env.get('FIREBASE_SERVICE_ACCOUNT_KEY'));
  if (!sa) return json({ error: 'FIREBASE_SERVICE_ACCOUNT_KEY is missing or invalid' }, 500);

  // قفڵ: هەر سکاڵایەک تەنها یەکجار
  const claim = await db(`complaints?id=eq.${id}&notified_at=is.null`, {
    method: 'PATCH',
    headers: { Prefer: 'return=representation' },
    body: JSON.stringify({ notified_at: new Date().toISOString() }),
  });
  if (!claim.ok) return json({ error: `db ${claim.status}`, detail: (await claim.text()).slice(0, 200) }, 500);
  const rows = await claim.json();
  if (!Array.isArray(rows) || rows.length === 0) return json({ skipped: 'already sent or not found' });
  const c = rows[0];

  const unclaim = () =>
    db(`complaints?id=eq.${id}`, { method: 'PATCH', body: JSON.stringify({ notified_at: null }) });

  try {
    const adminsRes = await db(
      'app_users?select=fcm_token&role=eq.admin&is_approved=eq.true&fcm_token=not.is.null',
    );
    const tokens = uniqueTokens(adminsRes.ok ? await adminsRes.json() : []);
    if (tokens.length === 0) return json({ sent: 0, skipped: 'no admin has notifications on' });

    const parts = [c.title, c.neighborhood_name].map((s) => String(s ?? '').trim()).filter(Boolean);
    const body = parts.length ? parts.join(' — ') : 'سکاڵایەکی نوێ گەیشت';
    const tag = `complaint-${c.id}`;
    const result = await sendFcm(sa, tokens.map((token) => ({
      token,
      notification: { title: TITLE, body },
      data: { type: 'complaint', complaint_id: String(c.id), tag },
      android: {
        priority: 'HIGH',
        notification: { tag, channel_id: 'high_importance_channel', sound: 'default' },
      },
    })));
    await clearTokens(db, result.invalidTokens);

    if (result.sent === 0 && result.invalidTokens.length < tokens.length) {
      await unclaim();
      return json({ error: 'nothing was delivered', failed: result.failed }, 502);
    }
    return json({ sent: result.sent, failed: result.failed, removedTokens: result.invalidTokens.length });
  } catch (e) {
    console.error('send-complaint-notification:', e);
    await unclaim();
    return json({ error: String(e).slice(0, 200) }, 500);
  }
}

Deno.serve(handle);
