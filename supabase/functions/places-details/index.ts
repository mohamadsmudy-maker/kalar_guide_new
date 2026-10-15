// supabase/functions/places-details/index.ts
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
    const { placeId } = await req.json();

    if (!placeId) {
      return new Response(
        JSON.stringify({ error: 'placeId پێویستە' }),
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
      'https://maps.googleapis.com/maps/api/place/details/json',
    );
    url.searchParams.set('place_id', placeId);
    url.searchParams.set('language', 'ku');
    url.searchParams.set(
      'fields',
      'name,formatted_address,geometry,formatted_phone_number,rating,types,photos',
    );
    url.searchParams.set('key', apiKey);

    const placesResponse = await fetch(url.toString());
    const data = await placesResponse.json();

    if (data.status !== 'OK') {
      console.error('Place details error:', data.status);
      return new Response(
        JSON.stringify({ error: data.status }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const result = data.result;

    // ✅ دروستکردنی photo URL
    let photoUrl: string | null = null;
    if (result.photos && result.photos.length > 0) {
      const photoRef = result.photos[0].photo_reference;
      photoUrl =
        `https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=${photoRef}&key=${apiKey}`;
    }

    return new Response(
      JSON.stringify({
        name: result.name ?? '',
        address: result.formatted_address ?? '',
        phone: result.formatted_phone_number ?? '',
        lat: result.geometry?.location?.lat,
        lng: result.geometry?.location?.lng,
        rating: result.rating ?? 0,
        types: result.types ?? [],
        photo: photoUrl,
        place_id: placeId,
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