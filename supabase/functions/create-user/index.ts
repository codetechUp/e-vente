// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), {
        status: 405,
        headers: { "Content-Type": "application/json" },
      });
    }

    const url = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!url || !serviceRoleKey) {
      return new Response(
        JSON.stringify({
          error:
            "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY env vars on function",
        }),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    const payload = await req.json();

    const email = String(payload.email ?? "").trim();
    const password = String(payload.password ?? "");
    const name = payload.name == null ? null : String(payload.name).trim();
    const phone = payload.phone == null ? null : String(payload.phone).trim();
    const role_id = payload.role_id == null ? null : Number(payload.role_id);
    const is_active = payload.is_active == null ? true : Boolean(payload.is_active);

    if (!email || !email.includes("@")) {
      return new Response(JSON.stringify({ error: "Invalid email" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    if (!password || password.length < 6) {
      return new Response(
        JSON.stringify({ error: "Password must be at least 6 characters" }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    const supabaseAdmin = createClient(url, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const { data: created, error: createErr } = await supabaseAdmin.auth.admin
      .createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          name,
          phone,
          role_id,
        },
      });

    if (createErr || !created?.user) {
      return new Response(
        JSON.stringify({
          error: createErr?.message ?? "Unable to create auth user",
        }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    const authUserId = created.user.id;

    const { error: upsertErr } = await supabaseAdmin
      .from("users")
      .upsert(
        {
          id: authUserId,
          name,
          email,
          phone,
          role_id,
          is_active,
        },
        { onConflict: "id" },
      );

    if (upsertErr) {
      return new Response(
        JSON.stringify({ error: upsertErr.message, user_id: authUserId }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    return new Response(JSON.stringify({ user_id: authUserId }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e: any) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
