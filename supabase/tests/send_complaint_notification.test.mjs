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
    complaint: {
      id: 12, title: 'خۆڵ و خاشاک', neighborhood_name: 'ئازادی', user_id: '4',
      status: 'pending', status_notified: 'pending', notified_at: null,
    },
    admins: [{ fcm_token: 'adm-1' }, { fcm_token: 'adm-1' }, { fcm_token: 'adm-2' }],
    citizen: [{ fcm_token: 'cit-4' }],
    queries: [],
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
  const q = Object.fromEntries(u.searchParams);
  const c = state.complaint;
  const method = init.method ?? 'GET';
  if (u.pathname === '/rest/v1/complaints' && method === 'GET') return res(q.id === `eq.${c.id}` ? [c] : []);
  if (u.pathname === '/rest/v1/complaints' && method === 'PATCH') {
    const patch = JSON.parse(init.body);
    if (q.id !== `eq.${c.id}`) return res([]);
    const matches = Object.entries(q).every(([k, v]) => {
      if (k === 'id') return true;
      if (v === 'is.null') return c[k] === null;
      if (v.startsWith('eq.')) return String(c[k]) === decodeURIComponent(v.slice(3));
      return true;
    });
    if (!matches) return res([]);
    Object.assign(c, patch);
    return res([c]);
  }
  if (u.pathname === '/rest/v1/app_users' && method === 'GET') {
    state.queries.push(q);
    if (q.role === 'eq.admin') return res(state.admins);
    if (q.id === 'eq.4') return res(state.citizen);
    return res([]);
  }
  throw new Error('unexpected fetch ' + url);
};

const { handle, STATUS_TEXT } = await import('../functions/send-complaint-notification/index.ts');
const call = (body) => handle(new Request('https://fn.test', { method: 'POST', body: JSON.stringify(body) }));
const tokens = () => state.fcm.map((m) => m.token).sort();

test('new complaint → every approved admin once; citizen not told about "pending"', async () => {
  const r = await call({ type: 'INSERT', table: 'complaints', record: { id: 12 } });
  const out = await r.json();
  assert.equal(r.status, 200, JSON.stringify(out));
  assert.deepEqual(tokens(), ['adm-1', 'adm-2']);
  assert.equal(state.fcm[0].notification.body, 'خۆڵ و خاشاک — ئازادی');
  assert.equal(state.fcm[0].android.notification.tag, 'complaint-12');
  assert.deepEqual(out.admins, { sent: 2, failed: 0, removedTokens: 0 });
  assert.match(out.citizen.skipped, /unchanged/);

  state.fcm = [];
  await call({ id: 12 });
  assert.equal(state.fcm.length, 0, 'second call sends nothing');
});

test('status change → only the citizen who sent it, once', async () => {
  state.complaint.notified_at = '2026-11-18T10:00:00Z';
  state.complaint.status = 'completed';
  const out = await (await call({ type: 'UPDATE', record: { id: 12 } })).json();
  assert.deepEqual(tokens(), ['cit-4']);
  assert.equal(state.fcm[0].notification.body, STATUS_TEXT.completed);
  assert.equal(state.fcm[0].data.status, 'completed');
  assert.equal(out.citizen.sent, 1);
  assert.equal(state.complaint.status_notified, 'completed');

  state.fcm = [];
  await call({ id: 12 });
  assert.equal(state.fcm.length, 0, 'same status is not sent twice');
});

test('complaint sent by a guest → nobody to tell', async () => {
  Object.assign(state.complaint, { notified_at: 'x', status: 'rejected', user_id: null });
  const out = await (await call({ record: { id: 12 } })).json();
  assert.match(out.citizen.skipped, /guest/);
  assert.equal(state.fcm.length, 0);
});

test('Firebase failure → both claims released for a retry', async () => {
  state.fcmStatus = 500;
  state.complaint.status = 'approved';
  const r = await call({ record: { id: 12 } });
  assert.equal(r.status, 502);
  assert.equal(state.complaint.notified_at, null);
  assert.equal(state.complaint.status_notified, 'pending');
});

test('missing Firebase key → clear error', async () => {
  const saved = env.FIREBASE_SERVICE_ACCOUNT_KEY;
  env.FIREBASE_SERVICE_ACCOUNT_KEY = '';
  const r = await call({ id: 12 });
  env.FIREBASE_SERVICE_ACCOUNT_KEY = saved;
  assert.equal(r.status, 500);
  assert.match((await r.json()).error, /FIREBASE_SERVICE_ACCOUNT_KEY/);
});
