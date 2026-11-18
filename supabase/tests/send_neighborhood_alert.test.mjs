// node --experimental-strip-types --test supabase/tests/send_neighborhood_alert.test.mjs
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
    alert: { id: 5, neighborhood_id: 2, neighborhood_name: 'ئازادی', title: 'بڕینی ئاو', body: 'سبەی لە ٩ تا ٢', notified_at: null },
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
  if (u.pathname === '/rest/v1/neighborhood_alerts' && init.method === 'PATCH') {
    const patch = JSON.parse(init.body);
    const a = state.alert;
    if (patch.notified_at === null) {
      a.notified_at = null;
      return res([]);
    }
    if (u.searchParams.get('id') !== `eq.${a.id}` || a.notified_at !== null) return res([]);
    a.notified_at = patch.notified_at;
    return res([a]);
  }
  throw new Error('unexpected fetch ' + url);
};

const { handle, topicFor } = await import('../functions/send-neighborhood-alert/index.ts');
const call = (body) => handle(new Request('https://fn.test', { method: 'POST', body: JSON.stringify(body) }));

test('alert → that neighborhood topic only, once', async () => {
  const out = await (await call({ type: 'INSERT', record: { id: 5 } })).json();
  assert.deepEqual(out, { sent: 1, topic: 'nbh_2' });
  assert.equal(state.fcm.length, 1);
  assert.equal(state.fcm[0].topic, topicFor(2));
  assert.equal(state.fcm[0].notification.title, '📍 ئازادی: بڕینی ئاو');
  assert.equal(state.fcm[0].notification.body, 'سبەی لە ٩ تا ٢');

  state.fcm = [];
  assert.match((await (await call({ id: 5 })).json()).skipped, /already sent/);
  assert.equal(state.fcm.length, 0);
});

test('Firebase failure → claim released', async () => {
  state.fcmStatus = 500;
  assert.equal((await call({ id: 5 })).status, 502);
  assert.equal(state.alert.notified_at, null);
});
