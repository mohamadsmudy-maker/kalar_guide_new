// supabase/functions/send-complaint-notification/index.ts
//
// 📣 ئاگاداری push بۆ سکاڵاکان. Database Webhook (Insert + Update لەسەر complaints)
// بانگی دەکات. دوو کار، هەر یەکەیان تەنها یەکجار:
//   ١. سکاڵای نوێ → هەموو ئەدمینە پەسەندکراوەکان   (قفڵ: complaints.notified_at)
//   ٢. دۆخی سکاڵا گۆڕا → ئەو هاوڵاتییەی ناردوویەتی  (قفڵ: complaints.status_notified)
// هاوڵاتی تەنها کاتێک وەری دەگرێت کە لە کاتی ناردندا چووبێتە ژوورەوە.
import {
  clearTokens, json, loadServiceAccount, recordId, sendFcm, supabaseRest, uniqueTokens,
  type ServiceAccount,
} from '../_shared/fcm.ts';

type Db = (path: string, init?: RequestInit) => Promise<Response>;
type Part = { status: number; body: Record<string, unknown> };

export const STATUS_TEXT: Record<string, string> = {
  approved: 'سکاڵاکەت پەسەند کرا',
  in_progress: 'کار لەسەر سکاڵاکەت دەکرێت',
  completed: 'سکاڵاکەت جێبەجێکرا ✅',
  rejected: 'سکاڵاکەت ڕەتکرایەوە',
};

const androidFor = (tag: string) => ({
  priority: 'HIGH',
  notification: { tag, channel_id: 'high_importance_channel', sound: 'default' },
});

async function notifyAdmins(db: Db, sa: ServiceAccount, id: number): Promise<Part> {
  const claim = await db(`complaints?id=eq.${id}&notified_at=is.null`, {
    method: 'PATCH',
    headers: { Prefer: 'return=representation' },
    body: JSON.stringify({ notified_at: new Date().toISOString() }),
  });
  if (!claim.ok) return { status: 500, body: { error: `db ${claim.status}` } };
  const rows = await claim.json();
  if (!Array.isArray(rows) || rows.length === 0) return { status: 200, body: { skipped: 'already sent or not found' } };
  const c = rows[0];
  const unclaim = () =>
    db(`complaints?id=eq.${id}`, { method: 'PATCH', body: JSON.stringify({ notified_at: null }) });

  try {
    const res = await db('app_users?select=fcm_token&role=eq.admin&is_approved=eq.true&fcm_token=not.is.null');
    const tokens = uniqueTokens(res.ok ? await res.json() : []);
    if (tokens.length === 0) return { status: 200, body: { sent: 0, skipped: 'no admin has notifications on' } };

    const parts = [c.title, c.neighborhood_name].map((s) => String(s ?? '').trim()).filter(Boolean);
    const tag = `complaint-${c.id}`;
    const result = await sendFcm(sa, tokens.map((token) => ({
      token,
      notification: { title: '📣 سکاڵای نوێ', body: parts.length ? parts.join(' — ') : 'سکاڵایەکی نوێ گەیشت' },
      data: { type: 'complaint', complaint_id: String(c.id), tag },
      android: androidFor(tag),
    })));
    await clearTokens(db, result.invalidTokens);
    if (result.sent === 0 && result.invalidTokens.length < tokens.length) {
      await unclaim();
      return { status: 502, body: { error: 'nothing was delivered', failed: result.failed } };
    }
    return { status: 200, body: { sent: result.sent, failed: result.failed, removedTokens: result.invalidTokens.length } };
  } catch (e) {
    console.error('notify admins:', e);
    await unclaim();
    return { status: 500, body: { error: String(e).slice(0, 200) } };
  }
}

async function notifyCitizen(db: Db, sa: ServiceAccount, id: number): Promise<Part> {
  const read = await db(`complaints?id=eq.${id}&select=id,title,status,status_notified,user_id`);
  if (!read.ok) return { status: 500, body: { error: `db ${read.status}` } };
  const c = (await read.json())?.[0];
  if (!c) return { status: 200, body: { skipped: 'not found' } };
  const status = String(c.status ?? '');
  const before = c.status_notified ?? null;
  if (!status || status === before) return { status: 200, body: { skipped: 'status unchanged' } };

  // قفڵ: تەنها ئەگەر دۆخەکە هێشتا هەمانە و هێشتا نەنێردراوە
  const filter = before == null ? 'status_notified=is.null' : `status_notified=eq.${encodeURIComponent(before)}`;
  const claim = await db(`complaints?id=eq.${id}&status=eq.${encodeURIComponent(status)}&${filter}`, {
    method: 'PATCH',
    headers: { Prefer: 'return=representation' },
    body: JSON.stringify({ status_notified: status }),
  });
  if (!claim.ok) return { status: 500, body: { error: `db ${claim.status}` } };
  const claimed = await claim.json();
  if (!Array.isArray(claimed) || claimed.length === 0) return { status: 200, body: { skipped: 'already sent' } };

  const text = STATUS_TEXT[status];
  const userId = String(c.user_id ?? '').trim();
  if (!text) return { status: 200, body: { skipped: `no message for status ${status}` } };
  if (!/^\d+$/.test(userId)) return { status: 200, body: { skipped: 'sent by a guest' } };

  const unclaim = () =>
    db(`complaints?id=eq.${id}`, { method: 'PATCH', body: JSON.stringify({ status_notified: before }) });

  try {
    const res = await db(`app_users?select=fcm_token&id=eq.${userId}&fcm_token=not.is.null`);
    const tokens = uniqueTokens(res.ok ? await res.json() : []);
    if (tokens.length === 0) return { status: 200, body: { sent: 0, skipped: 'citizen has notifications off' } };

    const tag = `complaint-status-${c.id}`;
    const result = await sendFcm(sa, tokens.map((token) => ({
      token,
      notification: { title: `📣 ${String(c.title ?? 'سکاڵا').trim() || 'سکاڵا'}`, body: text },
      data: { type: 'complaint_status', complaint_id: String(c.id), status, tag },
      android: androidFor(tag),
    })));
    await clearTokens(db, result.invalidTokens);
    if (result.sent === 0 && result.invalidTokens.length < tokens.length) {
      await unclaim();
      return { status: 502, body: { error: 'nothing was delivered', failed: result.failed } };
    }
    return { status: 200, body: { sent: result.sent, failed: result.failed } };
  } catch (e) {
    console.error('notify citizen:', e);
    await unclaim();
    return { status: 500, body: { error: String(e).slice(0, 200) } };
  }
}

export async function handle(req: Request): Promise<Response> {
  const db = supabaseRest();
  if (!db) return json({ error: 'supabase env missing' }, 500);

  const id = await recordId(req);
  if (id == null) return json({ error: 'complaint id required' }, 400);

  const sa = loadServiceAccount(Deno.env.get('FIREBASE_SERVICE_ACCOUNT_KEY'));
  if (!sa) return json({ error: 'FIREBASE_SERVICE_ACCOUNT_KEY is missing or invalid' }, 500);

  const admins = await notifyAdmins(db, sa, id);
  const citizen = await notifyCitizen(db, sa, id);
  return json({ admins: admins.body, citizen: citizen.body }, Math.max(admins.status, citizen.status));
}

Deno.serve(handle);
