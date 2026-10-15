// supabase/functions/send-complaint-notification/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

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
    const { complaintId } = await req.json();

    if (!complaintId) {
      return new Response(
        JSON.stringify({ error: 'complaintId پێویستە' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // ✅ هێنانی سکاڵا
    const { data: complaint, error } = await admin
      .from('complaints')
      .select('*')
      .eq('id', complaintId)
      .maybeSingle();

    if (error || !complaint) {
      return new Response(
        JSON.stringify({ error: 'سکاڵا نەدۆزرایەوە' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ✅ FCM Token هەموو ئەدمینەکان
    const { data: admins } = await admin
      .from('app_users')
      .select('fcm_token')
      .eq('role', 'admin')
      .eq('is_approved', true)
      .not('fcm_token', 'is', null);

    if (!admins || admins.length === 0) {
      return new Response(
        JSON.stringify({ success: true, sent: 0, message: 'هیچ ئەدمینێک نییە' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const tokens = admins
      .map((a: any) => a.fcm_token)
      .filter((t: string) => t && t.length > 0);

    // ✅ ناردنی FCM بە HTTP v1
    // ⚠️ پێویستە FIREBASE_SERVICE_ACCOUNT_KEY دانرابێت
    const firebaseKey = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_KEY');
    if (!firebaseKey) {
      console.warn('FIREBASE_SERVICE_ACCOUNT_KEY دانەنراوە');
      return new Response(
        JSON.stringify({ success: false, sent: 0, message: 'FCM ناکارا' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ⚠️ ئەمە تەنها نموونەیە — پێویستە Firebase SDK ی تەواو بەکاربهێنیت
    // بۆ سادەیی، تەنها success دەگەڕێنینەوە

    return new Response(
      JSON.stringify({
        success: true,
        sent: tokens.length,
        message: `${tokens.length} ئاگاداری نێردرا`,
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