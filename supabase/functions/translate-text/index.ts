// supabase/functions/translate-text/index.ts
//
// 🌍 وەرگێڕانی داتای داتابەیس (ناوی شوێن، بەش، وەسف...) لە کوردییەوە بۆ
// ئینگلیزی یان عەرەبی بە Gemini. ئەپەکە (TranslationService) ئەنجامەکە
// لە مۆبایلدا کاش دەکات، بۆیە هەر دەقێک تەنها یەکجار دەنێردرێت.
//
// Deploy:  supabase functions deploy translate-text
// پێویستی بە هەمان GEMINI_API_KEY ی gemini-proxy هەیە.
//
// Request:  { "text": "...", "targetLanguage": "en" | "ar" | "fa" }
// Response: { "translation": "..." }
//
// ناوی شوێن بۆ کوردی (ئەدمین ← «ناوە لاتینییەکان»):
// Request:  { "names": ["Kalar Hospital", ...], "mode": "to_kurdish" }
// Response: { "kurdish": ["نەخۆشخانەی کەلار", ...] }   (کاش ناکرێت)
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

// gemini-1.5-* لەلایەن Google ەوە لابراون (404). GEMINI_MODEL دەتوانێت
// مۆدێلێکی تر دیاری بکات؛ ئەگەر نەبوو، 404 بوو یان سنووری تەواو بوو (429)،
// دانەی دواتر تاقی دەکرێتەوە. flash-lite یەکەمە: سنووری بەخۆڕایی زیاترە.
const MODELS = [Deno.env.get('GEMINI_MODEL'), 'gemini-2.5-flash-lite', 'gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-flash-latest']
  .filter((m): m is string => !!m && !m.startsWith('gemini-1.5'));

async function callGemini(apiKey: string, apiVersion: string, prompt: string, jsonMode = false): Promise<Response> {
  let last: Response | null = null;
  for (const model of MODELS) {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/${apiVersion}/models/${model}:generateContent`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0,
            maxOutputTokens: jsonMode ? 8192 : 2048,
            ...(jsonMode ? { responseMimeType: 'application/json' } : {}),
            // وەرگێڕان پێویستی بە «بیرکردنەوە» نییە؛ بێ ئەمە تۆکنەکان دەخوات
            ...(model.startsWith('gemini-2.5') ? { thinkingConfig: { thinkingBudget: 0 } } : {}),
          },
        }),
      },
    );
    // 404/400 = مۆدێلەکە نییە؛ 429/403/503 = سنوور یان قەرەباڵغی ئەو مۆدێلە —
    // هەر مۆدێلێک سنووری جیاوازی هەیە، بۆیە دانەی دواتر تاقی دەکرێتەوە
    if (![400, 403, 404, 429, 503].includes(res.status)) return res;
    console.error(`model ${model}: ${res.status}`, await res.clone().text());
    last = res;
  }
  return last ?? new Response('no model', { status: 502 });
}

// ── کاشی هاوبەش (خشتەی text_translations) ─────────────────────────
// هەر دەقێک تەنها یەکجار بە Gemini وەردەگێڕدرێت؛ دواتر لێرەوە دێت.
// SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY خۆکارانە لە Edge Functions دا هەن.
const SB_URL = Deno.env.get('SUPABASE_URL');
const SB_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

async function rpc(name: string, args: Record<string, unknown>): Promise<unknown> {
  if (!SB_URL || !SB_KEY) return null;
  try {
    const res = await fetch(`${SB_URL}/rest/v1/rpc/${name}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: SB_KEY,
        Authorization: `Bearer ${SB_KEY}`,
      },
      body: JSON.stringify(args),
    });
    if (!res.ok) {
      console.error(`${name}:`, res.status, await res.text());
      return null;
    }
    return res.status === 204 ? null : await res.json();
  } catch (e) {
    console.error(`${name} exception:`, e);
    return null; // کاش نەبوو → هەر وەردەگێڕین
  }
}

const LANGS: Record<string, string> = { en: 'English', ar: 'Arabic', fa: 'Persian' };
const MAX_LEN = 5000;

const RULES =
  `Rules:\n` +
  `- Names of people, businesses, mosques, shops and brands: transliterate, do not translate literally.\n` +
  `- Generic words (hospital, municipality, directorate, neighborhood...) are translated.\n` +
  `- "کەلار" is "Kalar" in English, "كلار" in Arabic, and "کلار" in Persian.\n` +
  `- Keep numbers, emojis, phone numbers and URLs unchanged.\n`;

const MAX_BATCH = 50;
const MAX_BATCH_ITEM = 600;

/// چەند دەقێک بە یەک داواکاری (سنووری خولەکی Gemini ـی بەخۆڕایی)
async function translateBatch(texts: string[], lang: string, target: string): Promise<Response> {
  const sources = texts.map((t) => t.trim());
  const out: (string | null)[] = await Promise.all(
    sources.map(async (src) => {
      const c = await rpc('translation_get', { p_lang: lang, p_source: src });
      return typeof c === 'string' && c.trim() ? c : null;
    }),
  );
  const missing = sources.map((s, i) => (out[i] == null ? i : -1)).filter((i) => i >= 0);
  if (missing.length === 0) return json({ translations: out, cached: sources.length });

  const apiKey = Deno.env.get('GEMINI_API_KEY');
  if (!apiKey) return json({ error: 'GEMINI_API_KEY is not set' }, 500);
  const apiVersion = Deno.env.get('GEMINI_API_VERSION') ?? 'v1beta';

  const items = missing.map((i) => sources[i]);
  const prompt =
    `Translate every item of the JSON array below from Central Kurdish (Sorani) to ${target} ` +
    `for a city guide app about Kalar, Kurdistan Region, Iraq.\n` + RULES +
    `- Reply with ONLY a JSON array of strings: the same number of items (${items.length}), in the same order.\n\n` +
    JSON.stringify(items);

  const res = await callGemini(apiKey, apiVersion, prompt, true);
  if (!res.ok) {
    console.error('Gemini batch error:', res.status, await res.text());
    return json({ error: `Gemini error: ${res.status}`, translations: out }, res.status === 429 ? 429 : 502);
  }
  const data = await res.json();
  const raw = (data.candidates?.[0]?.content?.parts?.[0]?.text ?? '').trim();
  let arr: unknown;
  try {
    arr = JSON.parse(raw.replace(/^```(?:json)?\s*|\s*```$/g, ''));
  } catch {
    arr = null;
  }
  if (!Array.isArray(arr) || arr.length !== items.length) {
    console.error('batch: bad reply', raw.slice(0, 300));
    return json({ error: 'bad batch reply', translations: out }, 502);
  }
  await Promise.all(
    missing.map(async (idx, k) => {
      const t = typeof arr[k] === 'string' ? (arr[k] as string).trim() : '';
      if (!t) return;
      out[idx] = t;
      await rpc('translation_put', { p_lang: lang, p_source: sources[idx], p_translation: t });
    }),
  );
  return json({ translations: out });
}

/// ناوی شوێنەکان (ئینگلیزی/لاتینی/عەرەبی) ← کوردیی سۆرانی، وەک خەڵکی کەلار دەینووسن
async function toKurdish(names: string[]): Promise<Response> {
  const apiKey = Deno.env.get('GEMINI_API_KEY');
  if (!apiKey) return json({ error: 'GEMINI_API_KEY is not set' }, 500);
  const apiVersion = Deno.env.get('GEMINI_API_VERSION') ?? 'v1beta';
  const prompt =
    `Rewrite every place name in the JSON array below in Central Kurdish (Sorani, Arabic script) ` +
    `the way people in Kalar, Kurdistan Region, Iraq write it on signs.\n` +
    `Rules:\n` +
    `- Translate generic words: Hospital = نەخۆشخانە, Pharmacy = دەرمانخانە, School = قوتابخانە, ` +
    `Mosque = مزگەوت, Restaurant = چێشتخانە, Market/Supermarket = مارکێت, Bank = بانک, ` +
    `Hotel = هوتێل, Clinic = نۆرینگە, Bakery = نانەواخانە, Fuel/Gas station = بەنزینخانە, ` +
    `Directorate = بەڕێوەبەرایەتی, Municipality = شارەوانی.\n` +
    `- Write proper names, brands and people's names with Kurdish letters (transliterate, do not translate them).\n` +
    `- Kurdish word order: «نەخۆشخانەی کەلار», not «کەلار نەخۆشخانە». "Kalar" is "کەلار".\n` +
    `- If a name is already in Kurdish, return it unchanged. Keep numbers.\n` +
    `- Reply with ONLY a JSON array of strings: the same number of items (${names.length}), in the same order.\n\n` +
    JSON.stringify(names);
  const res = await callGemini(apiKey, apiVersion, prompt, true);
  if (!res.ok) {
    console.error('Gemini to_kurdish error:', res.status, await res.text());
    return json({ error: `Gemini error: ${res.status}` }, res.status === 429 ? 429 : 502);
  }
  const data = await res.json();
  const raw = (data.candidates?.[0]?.content?.parts?.[0]?.text ?? '').trim();
  let arr: unknown;
  try {
    arr = JSON.parse(raw.replace(/^```(?:json)?\s*|\s*```$/g, ''));
  } catch {
    arr = null;
  }
  if (!Array.isArray(arr) || arr.length !== names.length) {
    console.error('to_kurdish: bad reply', raw.slice(0, 300));
    return json({ error: 'bad reply' }, 502);
  }
  return json({ kurdish: arr.map((v) => (typeof v === 'string' ? v.trim() : '')) });
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const body = await req.json();
    const { text, texts, targetLanguage } = body;

    // ── ناوی شوێن ← کوردی ──
    if (body.mode === 'to_kurdish') {
      const names = Array.isArray(body.names)
        ? (body.names as unknown[]).filter((n): n is string => typeof n === 'string' && !!n.trim())
        : [];
      if (names.length === 0 || names.length > MAX_BATCH || names.some((n) => n.length > 200)) {
        return json({ error: 'names: 1-50 non-empty strings' }, 400);
      }
      return await toKurdish(names.map((n) => n.trim()));
    }
    const target = LANGS[targetLanguage];

    // ── بە کۆمەڵ: { texts: [...], targetLanguage } → { translations: [...] } ──
    if (Array.isArray(texts)) {
      if (!target) return json({ error: 'targetLanguage (en|ar) is required' }, 400);
      const list = texts.filter((t) => typeof t === 'string' && t.trim()) as string[];
      if (list.length === 0 || list.length !== texts.length) {
        return json({ error: 'texts must be non-empty strings' }, 400);
      }
      if (list.length > MAX_BATCH || list.some((t) => t.length > MAX_BATCH_ITEM)) {
        return json({ error: 'batch too large' }, 413);
      }
      return await translateBatch(list, targetLanguage, target);
    }

    if (typeof text !== 'string' || !text.trim() || !target) {
      return json({ error: 'text and targetLanguage (en|ar) are required' }, 400);
    }
    if (text.length > MAX_LEN) return json({ error: 'text too long' }, 413);

    const source = text.trim();
    const cached = await rpc('translation_get', { p_lang: targetLanguage, p_source: source });
    if (typeof cached === 'string' && cached.trim()) {
      return json({ translation: cached, cached: true });
    }

    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) return json({ error: 'GEMINI_API_KEY is not set' }, 500);
    const apiVersion = Deno.env.get('GEMINI_API_VERSION') ?? 'v1beta';

    const prompt =
      `Translate the following text from Central Kurdish (Sorani) to ${target} ` +
      `for a city guide app about Kalar, Kurdistan Region, Iraq.\n` + RULES +
      `- Reply with the translation only, no quotes and no explanation.\n\n` +
      `Text:\n${source}`;

    const res = await callGemini(apiKey, apiVersion, prompt);

    if (!res.ok) {
      console.error('Gemini error:', res.status, await res.text());
      return json({ error: `Gemini error: ${res.status}` }, res.status === 429 ? 429 : 502);
    }

    const data = await res.json();
    const translation = (data.candidates?.[0]?.content?.parts?.[0]?.text ?? '').trim();
    if (!translation) return json({ error: 'empty translation' }, 502);

    await rpc('translation_put', {
      p_lang: targetLanguage,
      p_source: source,
      p_translation: translation,
    });
    return json({ translation });
  } catch (e) {
    console.error('translate-text exception:', e);
    return json({ error: 'internal error' }, 500);
  }
});
