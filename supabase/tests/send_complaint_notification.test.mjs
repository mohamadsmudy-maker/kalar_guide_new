// node --experimental-strip-types --test supabase/tests/send_complaint_notification.test.mjs
// فەنکشنی send-complaint-notification بە Firebase و Supabase ـی ساختە تاقی دەکاتەوە.
import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync } from 'node:crypto';

const { privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const env = {
  SUPABASE_URL: 'https://db.test',
  SUPABASE_SERVICE_ROLE_KEY: 'service-key',
  FIREBASE_SERVICE_ACCOUNT_KEY: JSON.stringify({
    client_email: 'push@test.iam.gserviceaccount.com',
    project_id: 'kalar-test',
    private_key: privateKey.export({ type: 'pkcs8', format: 'pem' }),
  }),
};
globalThis.Deno = { env: { get: (k) => env[k] }, serve: () => {} };

let state;
beforeEach(() => {
  state = {
    complaint: { id: 12, title: 'خۆڵ و خاشاک', neighborhood_name: 'ئازادی', notified_at: null },
    admins: [{ fcm_token: 'adm-1' }, { fcm_token: 'adm-1' }, { fcm_token: 'adm-2' }],
    adminQuery: null,
    fcm: [],
    fcmStatus: 200,
  };
});

globalThis.fetch = async (url, init = {}) => {
  const u = new URL(url);
  const res = (body, status = 200) => new Response(JSON.stringify(body), { status });
  if (u.host === 'oauth2.googleapis.com') return res({ access_token: 'ya29.test' });
  if (u.host === 'fcm.googleapis.com') {
    state.fcm.push(JSON.parse(init.body).message);
    return res({}, state.fcmStatus);
  }
  const path = u.pathname;
  if (path === '/rest/v1/complaints' && init.method === 'PATCH') {
    const patch = JSON.parse(init.body);
    if (patch.notified_at === null) {
      state.complaint.notified_at = null;
      return res([]);
    }
    const c = state.complaint;
    if (u.searchParams.get('id') !== `eq.${c.id}` || c.notified_at !== null) return res([]);
    c.notified_at = patch.notified_at;
    return res([c]);
  }
  if (path === '/rest/v1/app_users' && (init.method ?? 'GET') === 'GET') {
    state.adminQuery = Object.fromEntries(u.searchParams);
    return res(state.admins);
  }
  throw new Error('unexpected fetch ' + url);
};

const { handle } = await import('../functions/send-complaint-notification/index.ts');
const call = (body) => handle(new Request('https://fn.test', { method: 'POST', body: JSON.stringify(body) }));

test('new complaint → every approved admin, once', async () => {
  const r = await call({ type: 'INSERT', table: 'complaints', record: { id: 12 } });
  const out = await r.json();
  assert.equal(r.status, 200, JSON.stringify(out));
  assert.equal(state.adminQuery.role, 'eq.admin');
  assert.equal(state.adminQuery.is_approved, 'eq.true');
  assert.deepEqual(state.fcm.map((m) => m.token).sort(), ['adm-1', 'adm-2']);
  assert.equal(state.fcm[0].notification.body, 'خۆڵ و خاشاک — ئازادی');
  assert.equal(state.fcm[0].data.complaint_id, '12');
  assert.equal(state.fcm[0].android.notification.tag, 'complaint-12');
  assert.deepEqual(out, { sent: 2, failed: 0, removedTokens: 0 });

  state.fcm = [];
  const again = await (await call({ id: 12 })).json();
  assert.match(again.skipped, /already sent/);
  assert.equal(state.fcm.length, 0);
});

test('no admin with notifications → nothing sent, no error', async () => {
  state.admins = [];
  const out = await (await call({ record: { id: 12 } })).json();
  assert.equal(out.sent, 0);
  assert.equal(state.fcm.length, 0);
});

test('Firebase failure → claim released for a retry', async () => {
  state.fcmStatus = 500;
  const r = await call({ record: { id: 12 } });
  assert.equal(r.status, 502);
  assert.equal(state.complaint.notified_at, null);
});

test('missing Firebase key → clear error', async () => {
  const saved = env.FIREBASE_SERVICE_ACCOUNT_KEY;
  env.FIREBASE_SERVICE_ACCOUNT_KEY = '';
  const r = await call({ id: 12 });
  env.FIREBASE_SERVICE_ACCOUNT_KEY = saved;
  assert.equal(r.status, 500);
  assert.match((await r.json()).error, /FIREBASE_SERVICE_ACCOUNT_KEY/);
});
