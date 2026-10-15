// supabase/functions/places-nearby/index.ts
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
    const { lat, lng, radius } = await req.json();

    if (lat == null || lng == null) {
      return new Response(
        JSON.stringify({ error: 'lat/lng پێویستن' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
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
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
    );
    url.searchParams.set('location', `${lat},${lng}`);
    url.searchParams.set('radius', String(radius ?? 50));
    url.searchParams.set('language', 'ku');
    url.searchParams.set('key', apiKey);

    const placesResponse = await fetch(url.toString());
    const data = await placesResponse.json();

    if (data.status !== 'OK' || !data.results || data.results.length === 0) {
      return new Response(
        JSON.stringify({ error: 'هیچ شوێنێک نەدۆزرایەوە' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const place = data.results[0];

    return new Response(
      JSON.stringify({
        name: place.name ?? '',
        address: place.vicinity ?? place.formatted_address ?? '',
        phone: '',
        lat: place.geometry?.location?.lat,
        lng: place.geometry?.location?.lng,
        rating: place.rating ?? 0,
        types: place.types ?? [],
        photo: null,
        place_id: place.place_id ?? '',
      }),
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