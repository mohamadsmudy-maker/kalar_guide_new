// supabase/functions/send-neighborhood-alert/index.ts
//
// 📍 ئاگاداری گەڕەک (بڕینی ئاو، کارەبا...). Database Webhook (Insert لەسەر
// neighborhood_alerts) بانگی دەکات و بۆ topic ـی nbh_<neighborhood_id> دەینێرێت،
// واتە تەنها ئەوانەی ئەو گەڕەکەیان لە ئەپدا هەڵبژاردووە. هەر ئاگادارییەک یەکجار.
import { json, loadServiceAccount, recordId, sendFcm, supabaseRest } from '../_shared/fcm.ts';

export const topicFor = (neighborhoodId: number | string) => `nbh_${neighborhoodId}`;

export async function handle(req: Request): Promise<Response> {
  const db = supabaseRest();
  if (!db) return json({ error: 'supabase env missing' }, 500);

  const id = await recordId(req);
  if (id == null) return json({ error: 'alert id required' }, 400);

  const sa = loadServiceAccount(Deno.env.get('FIREBASE_SERVICE_ACCOUNT_KEY'));
  if (!sa) return json({ error: 'FIREBASE_SERVICE_ACCOUNT_KEY is missing or invalid' }, 500);

  const claim = await db(`neighborhood_alerts?id=eq.${id}&notified_at=is.null`, {
    method: 'PATCH',
    headers: { Prefer: 'return=representation' },
    body: JSON.stringify({ notified_at: new Date().toISOString() }),
  });
  if (!claim.ok) return json({ error: `db ${claim.status}` }, 500);
  const rows = await claim.json();
  if (!Array.isArray(rows) || rows.length === 0) return json({ skipped: 'already sent or not found' });
  const a = rows[0];

  const unclaim = () =>
    db(`neighborhood_alerts?id=eq.${id}`, { method: 'PATCH', body: JSON.stringify({ notified_at: null }) });

  try {
    const place = String(a.neighborhood_name ?? '').trim();
    const tag = `nbh-alert-${a.id}`;
    const result = await sendFcm(sa, [{
      topic: topicFor(a.neighborhood_id),
      notification: {
        title: place ? `📍 ${place}: ${a.title}` : `📍 ${a.title}`,
        body: String(a.body ?? '').trim() || String(a.title),
      },
      data: { type: 'neighborhood_alert', neighborhood_id: String(a.neighborhood_id), tag },
      android: { priority: 'HIGH', notification: { tag, channel_id: 'high_importance_channel', sound: 'default' } },
    }]);
    if (result.sent === 0) {
      await unclaim();
      return json({ error: 'nothing was delivered' }, 502);
    }
    return json({ sent: result.sent, topic: topicFor(a.neighborhood_id) });
  } catch (e) {
    console.error('send-neighborhood-alert:', e);
    await unclaim();
    return json({ error: String(e).slice(0, 200) }, 500);
  }
}

Deno.serve(handle);
