// supabase/functions/translate-text/index.ts
//
// 🌍 وەرگێڕانی داتای داتابەیس (ناوی شوێن، بەش، وەسف...) لە کوردییەوە بۆ
// ئینگلیزی یان عەرەبی بە Gemini. ئەپەکە (TranslationService) ئەنجامەکە
// لە مۆبایلدا کاش دەکات، بۆیە هەر دەقێک تەنها یەکجار دەنێردرێت.
//
// Deploy:  supabase functions deploy translate-text
// پێویستی بە هەمان GEMINI_API_KEY ی gemini-proxy هەیە.
//
// Request:  { "text": "...", "targetLanguage": "en" | "ar" }
// Response: { "translation": "..." }
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
// مۆدێلێکی تر دیاری بکات؛ ئەگەر نەبوو یان 404 بوو، دانەی دواتر تاقی دەکرێتەوە.
const MODELS = [Deno.env.get('GEMINI_MODEL'), 'gemini-2.5-flash', 'gemini-flash-latest']
  .filter((m): m is string => !!m && !m.startsWith('gemini-1.5'));

async function callGemini(apiKey: string, apiVersion: string, prompt: string): Promise<Response> {
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
            maxOutputTokens: 2048,
            // وەرگێڕان پێویستی بە «بیرکردنەوە» نییە؛ بێ ئەمە تۆکنەکان دەخوات
            ...(model.startsWith('gemini-2.5') ? { thinkingConfig: { thinkingBudget: 0 } } : {}),
          },
        }),
      },
    );
    if (res.status !== 404 && res.status !== 400) return res;
    console.error(`model ${model}: ${res.status}`, await res.clone().text());
    last = res;
  }
  return last ?? new Response('no model', { status: 502 });
}

const LANGS: Record<string, string> = { en: 'English', ar: 'Arabic' };
const MAX_LEN = 5000;

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const { text, targetLanguage } = await req.json();
    const target = LANGS[targetLanguage];
    if (typeof text !== 'string' || !text.trim() || !target) {
      return json({ error: 'text and targetLanguage (en|ar) are required' }, 400);
    }
    if (text.length > MAX_LEN) return json({ error: 'text too long' }, 413);

    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) return json({ error: 'GEMINI_API_KEY is not set' }, 500);
    const apiVersion = Deno.env.get('GEMINI_API_VERSION') ?? 'v1beta';

    const prompt =
      `Translate the following text from Central Kurdish (Sorani) to ${target} ` +
      `for a city guide app about Kalar, Kurdistan Region, Iraq.\n` +
      `Rules:\n` +
      `- Names of people, businesses, mosques, shops and brands: transliterate, do not translate literally.\n` +
      `- Generic words (hospital, municipality, directorate, neighborhood...) are translated.\n` +
      `- "کەلار" is "Kalar" in English and "كلار" in Arabic.\n` +
      `- Keep numbers, emojis, phone numbers and URLs unchanged.\n` +
      `- Reply with the translation only, no quotes and no explanation.\n\n` +
      `Text:\n${text}`;

    const res = await callGemini(apiKey, apiVersion, prompt);

    if (!res.ok) {
      console.error('Gemini error:', res.status, await res.text());
      return json({ error: `Gemini error: ${res.status}` }, res.status === 429 ? 429 : 502);
    }

    const data = await res.json();
    const translation = (data.candidates?.[0]?.content?.parts?.[0]?.text ?? '').trim();
    if (!translation) return json({ error: 'empty translation' }, 502);

    return json({ translation });
  } catch (e) {
    console.error('translate-text exception:', e);
    return json({ error: 'internal error' }, 500);
  }
});
