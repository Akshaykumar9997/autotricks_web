// Controlled portal-access provisioning. There is no public signup path to a
// profile: only an existing ADMIN can invite a user, and the profile
// (role + client link) is created here with the service role. Authorization
// is decided from public.profiles, never from user-editable metadata.
import { createClient } from "npm:@supabase/supabase-js@2";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

const allowedOrigins = (Deno.env.get("ALLOWED_ORIGINS") ?? "*")
  .split(",")
  .map((o) => o.trim())
  .filter(Boolean);

function corsHeaders(origin: string | null): Record<string, string> {
  const allowOrigin = allowedOrigins.includes("*")
    ? "*"
    : origin && allowedOrigins.includes(origin)
    ? origin
    : allowedOrigins[0] ?? "null";
  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

function json(status: number, body: unknown, origin: string | null): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
  });
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim().replace(/\s+/g, " ") : "";
}

Deno.serve(async (req) => {
  const origin = req.headers.get("Origin");

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(origin) });
  }
  if (req.method !== "POST") {
    return json(405, { error: "Method not allowed" }, origin);
  }

  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!token) {
    return json(401, { error: "Authentication required" }, origin);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  // Validates the access token with Supabase Auth (works for any signing key type).
  const { data: authData, error: authError } = await admin.auth.getUser(token);
  if (authError || !authData?.user) {
    return json(401, { error: "Invalid or expired session" }, origin);
  }
  const callerId = authData.user.id;

  const { data: caller, error: callerError } = await admin
    .from("profiles")
    .select("role")
    .eq("id", callerId)
    .maybeSingle();
  if (callerError) {
    console.error("caller profile lookup failed", callerError);
    return json(500, { error: "Could not verify permissions" }, origin);
  }
  if (caller?.role !== "ADMIN") {
    return json(403, { error: "Admin access required" }, origin);
  }

  let body: Record<string, unknown>;
  try {
    const parsed = await req.json();
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("not an object");
    body = parsed as Record<string, unknown>;
  } catch {
    return json(400, { error: "Invalid JSON body" }, origin);
  }

  const email = text(body.email).toLowerCase();
  const fullName = text(body.full_name);
  const role = body.role;
  const clientId = body.client_id ?? null;
  const fields: Record<string, string> = {};

  if (email.length > 254 || !EMAIL_RE.test(email)) fields.email = "A valid email is required.";
  if (fullName.length < 2 || fullName.length > 100) fields.full_name = "Full name must be 2-100 characters.";
  if (role !== "CLIENT" && role !== "ADMIN") fields.role = "Role must be CLIENT or ADMIN.";
  if (role === "CLIENT" && (typeof clientId !== "string" || !UUID_RE.test(clientId))) {
    fields.client_id = "CLIENT users must be linked to an existing client.";
  }
  if (role === "ADMIN" && clientId !== null) {
    fields.client_id = "ADMIN users cannot be linked to a client.";
  }
  if (Object.keys(fields).length > 0) {
    return json(422, { error: "Validation failed", fields }, origin);
  }

  if (role === "CLIENT") {
    const { data: client, error: clientError } = await admin
      .from("clients")
      .select("id, is_active")
      .eq("id", clientId as string)
      .maybeSingle();
    if (clientError) {
      console.error("client lookup failed", clientError);
      return json(500, { error: "Could not verify the client" }, origin);
    }
    if (!client || !client.is_active) {
      return json(422, { error: "Validation failed", fields: { client_id: "Client not found or inactive." } }, origin);
    }
  }

  const redirectTo = typeof body.redirect_to === "string" && body.redirect_to !== ""
    ? body.redirect_to
    : Deno.env.get("INVITE_REDIRECT_URL") ?? undefined;

  const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, { redirectTo });
  if (inviteError || !invited?.user) {
    const alreadyExists = /already/i.test(inviteError?.message ?? "");
    console.error("invite failed", inviteError);
    return json(
      alreadyExists ? 409 : 502,
      { error: alreadyExists ? "A user with this email already exists" : "Could not send the invitation" },
      origin,
    );
  }

  const { error: profileError } = await admin.from("profiles").insert({
    id: invited.user.id,
    role,
    client_id: role === "CLIENT" ? clientId : null,
    full_name: fullName,
  });
  if (profileError) {
    console.error("profile insert failed; removing invited user", profileError);
    await admin.auth.admin.deleteUser(invited.user.id);
    return json(500, { error: "Could not create the profile; the invitation was rolled back" }, origin);
  }

  const { error: auditError } = await admin.from("audit_logs").insert({
    actor_profile_id: callerId,
    action: "USER_INVITED",
    entity_type: "profile",
    entity_id: invited.user.id,
    metadata: { role, client_id: role === "CLIENT" ? clientId : null, email },
  });
  if (auditError) console.error("audit insert failed", auditError);

  return json(201, {
    user_id: invited.user.id,
    email,
    role,
    client_id: role === "CLIENT" ? clientId : null,
  }, origin);
});
