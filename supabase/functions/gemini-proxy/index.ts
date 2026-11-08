// supabase/functions/gemini-proxy/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { prompt, base64Image, maxTokens, temperature } =
      await req.json();

    if (!prompt || prompt.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: 'Prompt بەتاڵە' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: 'GEMINI_API_KEY دانەنراوە' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const apiVersion = Deno.env.get('GEMINI_API_VERSION') ?? 'v1beta';
    // gemini-1.5-* لەلایەن Google ەوە لابراون (404)؛ یەک لە دوای یەک تاقی دەکرێنەوە
    const models = [Deno.env.get('GEMINI_MODEL'), 'gemini-2.5-flash', 'gemini-flash-latest']
      .filter((m): m is string => !!m && !m.startsWith('gemini-1.5'));

    // ✅ پێکهاتەکانی دەق
    const parts: any[] = [{ text: prompt }];

    // ✅ زیادکردنی وێنە ئەگەر هەبوو
    if (base64Image) {
      parts.push({
        inline_data: {
          mime_type: 'image/jpeg',
          data: base64Image,
        },
      });
    }

    // ✅ بانگکردن بە header (نەک URL)
    let response: Response = new Response('no model', { status: 502 });
    for (const model of models) {
      response = await fetch(
        `https://generativelanguage.googleapis.com/${apiVersion}/models/${model}:generateContent`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: JSON.stringify({
            contents: [{ parts }],
            generationConfig: {
              temperature: temperature ?? 0.7,
              maxOutputTokens: maxTokens ?? 2048,
              ...(model.startsWith('gemini-2.5') ? { thinkingConfig: { thinkingBudget: 0 } } : {}),
            },
          }),
        },
      );
      if (response.status !== 404 && response.status !== 400) break;
      console.error(`model ${model}:`, response.status, await response.clone().text());
    }

    if (!response.ok) {
      const errorText = await response.text();
      console.error('Gemini error:', response.status, errorText);

      if (response.status === 429) {
        return new Response(
          JSON.stringify({ error: 'زۆر داواکاریت ناردووە' }),
          { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }

      if (response.status === 401 || response.status === 403) {
        return new Response(
          JSON.stringify({ error: 'API Key هەڵەیە' }),
          { status: response.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }

      return new Response(
        JSON.stringify({ error: `Gemini error: ${response.status}` }),
        { status: response.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const data = await response.json();
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text ?? '';

    return new Response(
      JSON.stringify({ text }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    console.error('Exception:', e);
    return new Response(
      JSON.stringify({ error: 'هەڵەی ناوخۆیی' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});