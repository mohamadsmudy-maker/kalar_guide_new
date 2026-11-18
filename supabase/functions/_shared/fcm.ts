// supabase/functions/_shared/fcm.ts
//
// ناردنی ئاگاداری بە Firebase Cloud Messaging (HTTP v1) و یارمەتیدەری Supabase.
// Secret: FIREBASE_SERVICE_ACCOUNT_KEY = ناوەڕۆکی تەواوی فایلی JSON ـی
// Firebase ← Project settings ← Service accounts ← Generate new private key.

export type ServiceAccount = { client_email: string; private_key: string; project_id: string };
export type FcmMessage = Record<string, unknown>;

export const json = (body: unknown, status = 200) =>
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

/// fetch بۆ REST ـی Supabase بە service role (RLS تێناپەڕێت)
export function supabaseRest(): ((path: string, init?: RequestInit) => Promise<Response>) | null {
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !key) return null;
  return (path, init = {}) =>
    fetch(`${url}/rest/v1/${path}`, {
      ...init,
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        'Content-Type': 'application/json',
        ...(init.headers ?? {}),
      },
    });
}

/// OAuth access token لە service account ـەوە (JWT بە RS256)
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

/// هەموو نامەکان دەنێرێت (٢٠ پێکەوە). invalidTokens = مۆبایلی سڕاو یان ئەپی لابراو.
export async function sendFcm(
  sa: ServiceAccount,
  messages: FcmMessage[],
): Promise<{ sent: number; failed: number; invalidTokens: string[] }> {
  const access = await accessToken(sa);
  const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
  let sent = 0, failed = 0;
  const invalidTokens: string[] = [];
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
        invalidTokens.push(m.token);
      } else {
        console.error('fcm', r.status, t.slice(0, 200));
      }
    }));
  }
  return { sent, failed, invalidTokens };
}

/// token ـە مردووەکان لە app_users لادەبات
export async function clearTokens(
  db: (path: string, init?: RequestInit) => Promise<Response>,
  tokens: string[],
): Promise<void> {
  for (const t of tokens) {
    await db(`app_users?fcm_token=eq.${encodeURIComponent(t)}`, {
      method: 'PATCH',
      body: JSON.stringify({ fcm_token: null }),
    });
  }
}

export function uniqueTokens(rows: unknown): string[] {
  if (!Array.isArray(rows)) return [];
  return [...new Set(
    rows.map((u) => String((u as { fcm_token?: string | null }).fcm_token ?? '').trim())
      .filter((t) => t.length > 0),
  )];
}

/// ناسنامەی تۆمار لە Database Webhook ({ record: { id } }) یان بانگکردنی دەستی ({ id })
export async function recordId(req: Request): Promise<number | null> {
  try {
    const p = await req.json();
    const id = p?.record?.id ?? p?.id;
    return Number.isInteger(id) ? id : null;
  } catch {
    return null;
  }
}
