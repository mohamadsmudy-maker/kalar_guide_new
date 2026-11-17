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
//
// Secret: FIREBASE_SERVICE_ACCOUNT_KEY = ناوەڕۆکی تەواوی فایلی JSON ـی
// Firebase ← Project settings ← Service accounts ← Generate new private key.
// SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY خۆکارانە هەن.

export const TOPIC = 'breaking_news';
const TITLE = '⚡ هەواڵی بەپەلە';

type ServiceAccount = { client_email: string; private_key: string; project_id: string };

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

function b64url(data: ArrayBuffer | string): string {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : new Uint8Array(data);
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export function loadServiceAccount(raw: string | undefined): ServiceAccount | null {
  if (!raw) return null;
  try {
    const sa = JSON.parse(raw);
    return sa.client_email && sa.private_key && sa.project_id ? sa : null;
  } catch {
    return null;
  }
}

/// OAuth access token بۆ FCM HTTP v1 لە service account ـەوە (JWT بە RS256)
async function accessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${header}.${claims}`),
  );
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${header}.${claims}.${b64url(sig)}`,
    }),
  });
  if (!res.ok) throw new Error(`oauth ${res.status}: ${(await res.text()).slice(0, 200)}`);
  return (await res.json()).access_token;
}

export async function handle(req: Request): Promise<Response> {
  const env = (k: string) => Deno.env.get(k);
  const sbUrl = env('SUPABASE_URL');
  const sbKey = env('SUPABASE_SERVICE_ROLE_KEY');
  if (!sbUrl || !sbKey) return json({ error: 'supabase env missing' }, 500);

  const db = (path: string, init: RequestInit = {}) =>
    fetch(`${sbUrl}/rest/v1/${path}`, {
      ...init,
      headers: {
        apikey: sbKey,
        Authorization: `Bearer ${sbKey}`,
        'Content-Type': 'application/json',
        ...(init.headers ?? {}),
      },
    });

  // Database Webhook: { type, table, record, old_record }؛ یان بە دەست: { id }
  let id: unknown;
  try {
    const p = await req.json();
    id = p?.record?.id ?? p?.id;
  } catch {
    return json({ error: 'bad request' }, 400);
  }
  if (!Number.isInteger(id)) return json({ error: 'ticker id required' }, 400);

  const sa = loadServiceAccount(env('FIREBASE_SERVICE_ACCOUNT_KEY'));
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
    const users = usersRes.ok ? await usersRes.json() : [];
    const tokens = [...new Set(
      (users as { fcm_token: string | null }[])
        .map((u) => (u.fcm_token ?? '').trim())
        .filter((t) => t.length > 0),
    )];

    const tag = `breaking-${ticker.id}`;
    const base = {
      notification: { title: TITLE, body },
      data: { type: 'breaking_news', tag },
      android: {
        priority: 'HIGH',
        notification: { tag, channel_id: 'high_importance_channel', sound: 'default' },
      },
    };
    const messages: Record<string, unknown>[] = [
      { ...base, topic: TOPIC },
      ...tokens.map((token) => ({ ...base, token })),
    ];

    const access = await accessToken(sa);
    const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
    let sent = 0, failed = 0;
    const invalid: string[] = [];
    for (let i = 0; i < messages.length; i += 20) {
      await Promise.all(messages.slice(i, i + 20).map(async (m) => {
        const r = await fetch(url, {
          method: 'POST',
          headers: { Authorization: `Bearer ${access}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ message: m }),
        });
        if (r.ok) {
          sent++;
          return;
        }
        failed++;
        const t = await r.text();
        if (r.status === 404 && /UNREGISTERED/.test(t) && typeof m.token === 'string') {
          invalid.push(m.token);
        } else {
          console.error('fcm', r.status, t.slice(0, 200));
        }
      }));
    }

    // token ـی مۆبایلی سڕاوە یان ئەپی لابراو
    for (const t of invalid) {
      await db(`app_users?fcm_token=eq.${encodeURIComponent(t)}`, {
        method: 'PATCH',
        body: JSON.stringify({ fcm_token: null }),
      });
    }

    if (sent === 0) {
      await unclaim();
      return json({ error: 'nothing was delivered', failed }, 502);
    }
    return json({ sent, failed, removedTokens: invalid.length });
  } catch (e) {
    console.error('send-breaking-news:', e);
    await unclaim();
    return json({ error: String(e).slice(0, 200) }, 500);
  }
}

Deno.serve(handle);
