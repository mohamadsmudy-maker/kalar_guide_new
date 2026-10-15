// supabase/functions/register-vendor/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // ✅ CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // ═══════════════════════════════════════════════════════
    // 📥 وەرگرتنی داتا
    // ═══════════════════════════════════════════════════════
    const { storeId, name, phone, password, inviteCode } = await req.json();

    // ═══════════════════════════════════════════════════════
    // ✅ پشکنینەکان
    // ═══════════════════════════════════════════════════════
    if (!storeId || !name || !phone || !password || !inviteCode) {
      return new Response(
        JSON.stringify({ error: 'هەموو خانەکان پێویستن' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    if (name.trim().length < 2) {
      return new Response(
        JSON.stringify({ error: 'ناو زۆر کورتە' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    if (phone.length < 10) {
      return new Response(
        JSON.stringify({ error: 'ژمارەی مۆبایل دروست نییە' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    if (password.length < 60) {
      // bcrypt hash = 60 chars
      return new Response(
        JSON.stringify({ error: 'پاسۆرد پێویستە hash بێت' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ═══════════════════════════════════════════════════════
    // 🔐 دروستکردنی Service Role Client
    // ═══════════════════════════════════════════════════════
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // ═══════════════════════════════════════════════════════
    // 🏪 پشکنینی شوێنەکە
    // ═══════════════════════════════════════════════════════
    const { data: store, error: storeError } = await admin
      .from('dukan')
      .select('id, name, invite_code')
      .eq('id', storeId)
      .maybeSingle();

    if (storeError || !store) {
      return new Response(
        JSON.stringify({ error: 'شوێن نەدۆزرایەوە' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ═══════════════════════════════════════════════════════
    // 🔑 پشکنینی invite code
    // ═══════════════════════════════════════════════════════
    if (store.invite_code !== inviteCode.trim()) {
      return new Response(
        JSON.stringify({ error: 'کۆدی نهێنی هەڵەیە' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ═══════════════════════════════════════════════════════
    // 🔍 پشکنینی دووبارەبوون
    // ═══════════════════════════════════════════════════════
    const { data: existingRequest } = await admin
      .from('vendor_registration_requests')
      .select('id, status')
      .eq('applicant_phone', phone)
      .maybeSingle();

    if (existingRequest) {
      const status = existingRequest.status;
      const message = status === 'pending'
        ? 'پێشتر داواکاریت ناردووە — چاوەڕوان بە'
        : status === 'approved'
        ? 'داواکاریت پەسەند کراوە — بچۆ ژوورەوە'
        : 'داواکاریت ڕەتکراوەتەوە — پەیوەندی بە ئەدمین بکە';

      return new Response(
        JSON.stringify({ error: message }),
        { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ✅ پشکنینی ئەگەر phone لە app_users هەیە
    const { data: existingUser } = await admin
      .from('app_users')
      .select('id')
      .eq('phone', phone)
      .maybeSingle();

    if (existingUser) {
      return new Response(
        JSON.stringify({ error: 'ئەم ژمارەیە پێشتر تۆمار کراوە' }),
        { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ═══════════════════════════════════════════════════════
    // 📝 Insert داواکاری
    // ═══════════════════════════════════════════════════════
    const { error: insertError } = await admin
      .from('vendor_registration_requests')
      .insert({
        store_id: storeId,
        applicant_name: name.trim(),
        applicant_phone: phone,
        password_hash: password, // bcrypt hash لە client
        invite_code: inviteCode.trim(),
        status: 'pending',
      });

    if (insertError) {
      console.error('Insert error:', insertError);
      return new Response(
        JSON.stringify({ error: insertError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ═══════════════════════════════════════════════════════
    // ✅ سەرکەوتوو
    // ═══════════════════════════════════════════════════════
    return new Response(
      JSON.stringify({
        success: true,
        message: 'داواکاریت نێردرا — چاوەڕوانی پەسەندی ئەدمین بە ⏳',
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    console.error('Unexpected error:', e);
    return new Response(
      JSON.stringify({ error: 'هەڵەی ناوخۆیی: ' + e.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});