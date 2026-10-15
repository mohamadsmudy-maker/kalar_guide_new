// supabase/functions/places-search/index.ts
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
    const { query, biasLat, biasLng, radius } = await req.json();

    if (!query || query.trim().length < 2) {
      return new Response(
        JSON.stringify({ results: [] }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const apiKey = Deno.env.get('GOOGLE_PLACES_API_KEY');
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: 'API key not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const url = new URL(
      'https://maps.googleapis.com/maps/api/place/textsearch/json',
    );
    url.searchParams.set('query', query.trim());
    url.searchParams.set('language', 'ku');
    url.searchParams.set('key', apiKey);

    if (biasLat != null && biasLng != null) {
      url.searchParams.set('location', `${biasLat},${biasLng}`);
      url.searchParams.set('radius', String(radius ?? 30000));
    }

    const placesResponse = await fetch(url.toString());
    const data = await placesResponse.json();

    if (data.status !== 'OK' && data.status !== 'ZERO_RESULTS') {
      console.error('Places error:', data.status, data.error_message);
      return new Response(
        JSON.stringify({ results: [], status: data.status }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ✅ تەنها داتای پێویست بگەڕێنەوە
    const results = (data.results ?? []).map((r: any) => ({
      name: r.name,
      address: r.formatted_address,
      lat: r.geometry?.location?.lat,
      lng: r.geometry?.location?.lng,
      place_id: r.place_id,
      rating: r.rating ?? 0,
      types: r.types ?? [],
    }));

    return new Response(
      JSON.stringify({ results }),
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