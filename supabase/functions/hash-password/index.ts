import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  const { password } = await req.json()
  const salt = Deno.env.get('PASSWORD_SALT') // کلیلەکە لێرەوە دەخوێنرێتەوە

  // لێرەدا کۆدی هاشکردنەکە دابنێ (بۆ نموونە SHA-256)
  // ...

  return new Response(JSON.stringify({ hashed: "..." }), {
    headers: { "Content-Type": "application/json" },
  })
})