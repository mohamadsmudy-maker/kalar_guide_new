// supabase/functions/send-breaking-news/index.ts
//
// ⚡ ئاگاداری push بۆ هەواڵی بەپەلە (news_tickers).
// Database Webhook (Insert + Update لەسەر news_tickers) ئەم فەنکشنە بانگ دەکات.
// هەر هەواڵێک تەنها یەکجار دەنێردرێت: ستوونی notified_at وەک «قفڵ» بەکاردێت،
// بۆیە بانگکردنی دووبارە (یان لە لایەن کەسێکی ترەوە) هیچ ئاگادارییەکی زیادە نانێرێت.
//
// دەنێردرێت بۆ:
//   • topic ـی breaking_news (هەموو ئەو مۆبایلانەی وەشانی نوێی ئەپیان هەیە، میوانیش)
//   • هەموو fcm_token ـەکانی app_users (وەشانی کۆن، تەنها ئەوانەی چوونەتە ژوورەوە)
// android.notification.tag یەکسانە، بۆیە ئەگەر هەردووکیان گەیشتن تەنها یەکێک دەمێنێتەوە.
import {
  clearTokens, json, loadServiceAccount, recordId, sendFcm, supabaseRest, uniqueTokens,
} from '../_shared/fcm.ts';

export const TOPIC = 'breaking_news';
const TITLE = '⚡ هەواڵی بەپەلە';

export async function handle(req: Request): Promise<Response> {
  const db = supabaseRest();
  if (!db) return json({ error: 'supabase env missing' }, 500);

  const id = await recordId(req);
  if (id == null) return json({ error: 'ticker id required' }, 400);

  const sa = loadServiceAccount(Deno.env.get('FIREBASE_SERVICE_ACCOUNT_KEY'));
  if (!sa) return json({ error: 'FIREBASE_SERVICE_ACCOUNT_KEY is missing or invalid' }, 500);

  // قفڵ: تەنها یەکەم بانگکردن بۆ هەواڵێکی چالاک کە هێشتا نەنێردراوە سەردەکەوێت
  const claim = await db(`news_tickers?id=eq.${id}&is_active=eq.true&notified_at=is.null`, {
    method: 'PATCH',
    headers: { Prefer: 'return=representation' },
    body: JSON.stringify({ notified_at: new Date().toISOString() }),
  });
  if (!claim.ok) return json({ error: `db ${claim.status}`, detail: (await claim.text()).slice(0, 200) }, 500);
  const rows = await claim.json();
  if (!Array.isArray(rows) || rows.length === 0) {
    return json({ skipped: 'inactive, already sent, or not found' });
  }
  const ticker = rows[0];
  const body = String(ticker.text_ku ?? '').trim();
  if (!body) return json({ skipped: 'empty text' });

  const unclaim = () =>
    db(`news_tickers?id=eq.${id}`, { method: 'PATCH', body: JSON.stringify({ notified_at: null }) });

  try {
    const usersRes = await db('app_users?select=fcm_token&fcm_token=not.is.null');
    const tokens = uniqueTokens(usersRes.ok ? await usersRes.json() : []);

    const tag = `breaking-${ticker.id}`;
    const base = {
      notification: { title: TITLE, body },
      data: { type: 'breaking_news', tag },
      android: {
        priority: 'HIGH',
        notification: { tag, channel_id: 'high_importance_channel', sound: 'default' },
      },
    };
    const result = await sendFcm(sa, [
      { ...base, topic: TOPIC },
      ...tokens.map((token) => ({ ...base, token })),
    ]);
    await clearTokens(db, result.invalidTokens);

    if (result.sent === 0) {
      await unclaim();
      return json({ error: 'nothing was delivered', failed: result.failed }, 502);
    }
    return json({ sent: result.sent, failed: result.failed, removedTokens: result.invalidTokens.length });
  } catch (e) {
    console.error('send-breaking-news:', e);
    await unclaim();
    return json({ error: String(e).slice(0, 200) }, 500);
  }
}

Deno.serve(handle);
