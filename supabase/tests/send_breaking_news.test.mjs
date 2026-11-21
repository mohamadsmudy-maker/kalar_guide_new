// node --experimental-strip-types --test supabase/tests/send_breaking_news.test.mjs
// فەنکشنی send-breaking-news بە Firebase و Supabase ـی ساختە تاقی دەکاتەوە.
import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, createVerify } from 'node:crypto';

const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const SA = {
  client_email: 'push@test.iam.gserviceaccount.com',
  project_id: 'kalar-test',
  private_key: privateKey.export({ type: 'pkcs8', format: 'pem' }),
};

const env = {
  SUPABASE_URL: 'https://db.test',
  SUPABASE_SERVICE_ROLE_KEY: 'service-key',
  FIREBASE_SERVICE_ACCOUNT_KEY: JSON.stringify(SA),
};
globalThis.Deno = { env: { get: (k) => env[k] }, serve: () => {} };

let state;
beforeEach(() => {
  state = {
    ticker: { id: 7, text_ku: 'بڕینی ئاو لە گەڕەکی ئازادی', is_active: true, notified_at: null },
    tokens: ['tok-a', 'tok-a', 'tok-dead', 'tok-b', null],
    fcm: [],
    cleared: [],
    jwtOk: null,
  };
});

globalThis.fetch = async (url, init = {}) => {
  const u = new URL(url);
  const res = (body, status = 200) => new Response(JSON.stringify(body), { status });
  if (u.host === 'oauth2.googleapis.com') {
    const assertion = new URLSearchParams(init.body.toString()).get('assertion');
    const [h, c, s] = assertion.split('.');
    const v = createVerify('RSA-SHA256');
    v.update(`${h}.${c}`);
    state.jwtOk = v.verify(publicKey, Buffer.from(s, 'base64url'));
    const claims = JSON.parse(Buffer.from(c, 'base64url').toString());
    assert.equal(claims.iss, SA.client_email);
    assert.match(claims.scope, /firebase\.messaging/);
    return res({ access_token: 'ya29.test' });
  }
  if (u.host === 'fcm.googleapis.com') {
    assert.equal(u.pathname, '/v1/projects/kalar-test/messages:send');
    assert.equal(init.headers.Authorization, 'Bearer ya29.test');
    const { message } = JSON.parse(init.body);
    state.fcm.push(message);
    if (message.token === 'tok-dead') return res({ error: { status: 'NOT_FOUND', details: [{ errorCode: 'UNREGISTERED' }] } }, 404);
    return res({ name: 'projects/kalar-test/messages/1' });
  }
  assert.equal(u.host, 'db.test');
  assert.equal(init.headers.Authorization, 'Bearer service-key');
  const path = u.pathname + u.search;
  if (path.startsWith('/rest/v1/news_tickers') && init.method === 'PATCH') {
    const patch = JSON.parse(init.body);
    if (patch.notified_at === null) {
      state.ticker.notified_at = null;
      return res([]);
    }
    const t = state.ticker;
    const claimable = u.searchParams.get('id') === `eq.${t.id}` && t.is_active && t.notified_at === null;
    if (!claimable) return res([]);
    t.notified_at = patch.notified_at;
    return res([t]);
  }
  if (path.startsWith('/rest/v1/app_users') && (init.method ?? 'GET') === 'GET') {
    return res(state.tokens.map((fcm_token) => ({ fcm_token })));
  }
  if (path.startsWith('/rest/v1/app_users') && init.method === 'PATCH') {
    state.cleared.push(u.searchParams.get('fcm_token').replace(/^eq\./, ''));
    return res([]);
  }
  throw new Error('unexpected fetch ' + url);
};

const { handle, TOPIC } = await import('../functions/send-breaking-news/index.ts');
const call = (body) => handle(new Request('https://fn.test', { method: 'POST', body: JSON.stringify(body) }));

test('webhook insert → topic only (users opt out by unsubscribing), once', async () => {
  const r = await call({ type: 'INSERT', table: 'news_tickers', record: { id: 7 } });
  const out = await r.json();
  assert.equal(r.status, 200, JSON.stringify(out));
  assert.equal(state.jwtOk, true, 'JWT is signed with the service account key');
  assert.deepEqual(state.fcm.map((m) => m.topic ?? m.token), [TOPIC]);
  for (const m of state.fcm) {
    assert.equal(m.notification.body, 'بڕینی ئاو لە گەڕەکی ئازادی');
    assert.equal(m.android.notification.tag, 'breaking-7');
    assert.equal(m.data.tag, 'breaking-7');
  }
  assert.deepEqual(out, { sent: 1, failed: 0 });
  assert.ok(state.ticker.notified_at);

  // دووبارە بانگکردن: هیچ ناردنێکی تر نییە
  state.fcm = [];
  const again = await (await call({ id: 7 })).json();
  assert.match(again.skipped, /already sent/);
  assert.equal(state.fcm.length, 0);
});

test('inactive ticker is not sent', async () => {
  state.ticker.is_active = false;
  const out = await (await call({ record: { id: 7 } })).json();
  assert.match(out.skipped, /inactive/);
  assert.equal(state.fcm.length, 0);
});

test('missing Firebase key → clear error, nothing claimed', async () => {
  const saved = env.FIREBASE_SERVICE_ACCOUNT_KEY;
  env.FIREBASE_SERVICE_ACCOUNT_KEY = '';
  const r = await call({ id: 7 });
  env.FIREBASE_SERVICE_ACCOUNT_KEY = saved;
  assert.equal(r.status, 500);
  assert.match((await r.json()).error, /FIREBASE_SERVICE_ACCOUNT_KEY/);
  assert.equal(state.ticker.notified_at, null);
});

test('bad request body → 400', async () => {
  assert.equal((await call({ record: { id: 'x' } })).status, 400);
});
