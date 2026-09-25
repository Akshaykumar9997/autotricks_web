import { createClient } from "npm:@supabase/supabase-js@2";

interface NotificationRow {
  id: string;
  profile_id: string;
  type: string;
  title: string;
  message: string;
  entity_type: string | null;
  entity_id: string | null;
  created_at: string;
}

interface DeviceTokenRow {
  id: string;
  fcm_token: string;
  platform: string;
  is_active: boolean;
}

interface PushDeliveryRow {
  id: string;
  notification_id: string;
  device_token_id: string;
  status: "PENDING" | "SENT" | "FAILED";
  attempt_count: number;
  sent_at: string | null;
  last_attempt_at: string;
  error_message: string | null;
}

interface ServiceAccountKey {
  project_id: string;
  client_email: string;
  private_key: string;
}

function base64UrlEncode(data: Uint8Array | string): string {
  const base64 =
    typeof data === "string"
      ? btoa(data)
      : btoa(String.fromCharCode(...data));
  return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToBinary(pem: string): Uint8Array {
  const cleanPem = pem
    .replace(/-----BEGIN [A-Z ]+-----/g, "")
    .replace(/-----END [A-Z ]+-----/g, "")
    .replace(/\s+/g, "");
  const binaryString = atob(cleanPem);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes;
}

async function getGoogleAccessToken(
  serviceAccount: ServiceAccountKey,
): Promise<string> {
  const header = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;

  const keyBytes = pemToBinary(serviceAccount.private_key);
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedToken),
  );

  const signedJwt = `${unsignedToken}.${base64UrlEncode(
    new Uint8Array(signature),
  )}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: signedJwt,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Failed to obtain Google access token: ${errorText}`);
  }

  const data = await response.json();
  return data.access_token as string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, content-type",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const notificationId =
      body.notification_id || body.record?.id || body.id;

    if (!notificationId) {
      return new Response(
        JSON.stringify({ error: "Missing notification_id" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // 1. Fetch authoritative notification row
    const { data: notification, error: notifError } = await supabase
      .from("notifications")
      .select("*")
      .eq("id", notificationId)
      .maybeSingle<NotificationRow>();

    if (notifError || !notification) {
      console.warn(`[push-dispatcher] Notification ${notificationId} not found`);
      return new Response(
        JSON.stringify({ error: "Notification not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } },
      );
    }

    // 2. Fetch active device tokens for profile
    const { data: tokens, error: tokensError } = await supabase
      .from("device_tokens")
      .select("id, fcm_token, platform, is_active")
      .eq("profile_id", notification.profile_id)
      .eq("is_active", true)
      .returns<DeviceTokenRow[]>();

    if (tokensError) {
      console.error("[push-dispatcher] Error fetching device tokens:", tokensError);
      return new Response(
        JSON.stringify({ error: "Failed to fetch device tokens" }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    if (!tokens || tokens.length === 0) {
      console.log(
        `[push-dispatcher] No active tokens for profile ${notification.profile_id}`,
      );
      return new Response(
        JSON.stringify({
          success: true,
          delivered: 0,
          message: "No active device tokens found",
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    // 3. Read Firebase service account secret
    const serviceAccountRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountRaw) {
      console.warn(
        "[push-dispatcher] FIREBASE_SERVICE_ACCOUNT secret is not configured in Supabase. Set via 'supabase secrets set FIREBASE_SERVICE_ACCOUNT=...'",
      );
      return new Response(
        JSON.stringify({
          success: false,
          warning:
            "FIREBASE_SERVICE_ACCOUNT secret missing in Supabase Edge Function",
          target_tokens: tokens.length,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    let serviceAccount: ServiceAccountKey;
    try {
      serviceAccount = JSON.parse(serviceAccountRaw);
    } catch {
      throw new Error("Invalid JSON in FIREBASE_SERVICE_ACCOUNT secret");
    }

    const projectId = serviceAccount.project_id || "autotricks-6485f";
    const accessToken = await getGoogleAccessToken(serviceAccount);

    let sent = 0;
    let failed = 0;
    let stale = 0;
    let skipped = 0;

    for (const token of tokens) {
      // 4. Idempotency Check: verify if already sent to this device token
      const { data: existingDelivery } = await supabase
        .from("notification_push_deliveries")
        .select("*")
        .eq("notification_id", notification.id)
        .eq("device_token_id", token.id)
        .maybeSingle<PushDeliveryRow>();

      if (existingDelivery && existingDelivery.status === "SENT") {
        console.log(
          `[push-dispatcher] Notification ${notification.id} already delivered to token ${token.id}. Skipping duplicate send.`,
        );
        skipped++;
        continue;
      }

      const attemptCount = (existingDelivery?.attempt_count || 0) + 1;

      // Upsert delivery tracking record to PENDING
      const { data: deliveryRecord, error: upsertErr } = await supabase
        .from("notification_push_deliveries")
        .upsert(
          {
            id: existingDelivery?.id,
            notification_id: notification.id,
            device_token_id: token.id,
            status: "PENDING",
            attempt_count: attemptCount,
            last_attempt_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          },
          { onConflict: "notification_id,device_token_id" },
        )
        .select()
        .single<PushDeliveryRow>();

      if (upsertErr) {
        console.warn("[push-dispatcher] Error upserting delivery record:", upsertErr);
      }

      const deliveryId = deliveryRecord?.id || existingDelivery?.id;

      const fcmMessage = {
        message: {
          token: token.fcm_token,
          notification: {
            title: notification.title,
            body: notification.message,
          },
          data: {
            notification_id: notification.id,
            type: notification.type,
            entity_type: notification.entity_type || "",
            entity_id: notification.entity_id || "",
          },
          android: {
            priority: "HIGH",
            notification: {
              channel_id: "autotricks_high_importance",
              sound: "default",
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
          },
        },
      };

      try {
        const fcmResponse = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify(fcmMessage),
          },
        );

        if (fcmResponse.ok) {
          sent++;
          if (deliveryId) {
            await supabase
              .from("notification_push_deliveries")
              .update({
                status: "SENT",
                sent_at: new Date().toISOString(),
                error_message: null,
                updated_at: new Date().toISOString(),
              })
              .eq("id", deliveryId);
          }
        } else {
          failed++;
          const errData = await fcmResponse.json().catch(() => ({}));
          const errCode =
            errData?.error?.details?.[0]?.errorCode ||
            errData?.error?.status ||
            fcmResponse.status;
          const errMsg = JSON.stringify(errData);

          console.warn(
            `[push-dispatcher] FCM send failure for token ${token.fcm_token.slice(0, 10)}...:`,
            errData,
          );

          if (deliveryId) {
            await supabase
              .from("notification_push_deliveries")
              .update({
                status: "FAILED",
                error_message: errMsg,
                updated_at: new Date().toISOString(),
              })
              .eq("id", deliveryId);
          }

          // Stale token detection: mark inactive if unregistered/invalid
          if (
            fcmResponse.status === 404 ||
            errCode === "UNREGISTERED" ||
            errCode === "NOT_FOUND" ||
            errCode === "INVALID_ARGUMENT"
          ) {
            stale++;
            await supabase
              .from("device_tokens")
              .update({ is_active: false })
              .eq("fcm_token", token.fcm_token);
            console.log(
              `[push-dispatcher] Marked stale token ${token.fcm_token.slice(0, 10)}... as inactive`,
            );
          }
        }
      } catch (err) {
        failed++;
        console.error("[push-dispatcher] Network exception sending FCM:", err);
        if (deliveryId) {
          await supabase
            .from("notification_push_deliveries")
            .update({
              status: "FAILED",
              error_message: err instanceof Error ? err.message : String(err),
              updated_at: new Date().toISOString(),
            })
            .eq("id", deliveryId);
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        notification_id: notification.id,
        total_tokens: tokens.length,
        sent,
        failed,
        stale,
        skipped,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("[push-dispatcher] Uncaught error:", err);
    return new Response(
      JSON.stringify({ error: err instanceof Error ? err.message : String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
