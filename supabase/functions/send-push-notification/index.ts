import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v4.14.4/index.ts";

interface NotificationPayload {
  record: {
    id: string;
    user_id: string;
    type: string;
    job_id?: string;
    body: string;
  };
}

async function getAccessToken(clientEmail: string, privateKey: string): Promise<string> {
  const cleanKey = privateKey.replace(/\\n/g, "\n");
  const key = await importPKCS8(cleanKey, "RS256");

  const now = Math.floor(Date.now() / 1000);
  const jwt = await new SignJWT({
    iss: clientEmail,
    sub: clientEmail,
    aud: "https://oauth2.googleapis.com/token",
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const data = await res.json();
  if (!res.ok) {
    throw new Error(`Failed to get Google access token: ${JSON.stringify(data)}`);
  }
  return data.access_token;
}

serve(async (req: Request) => {
  try {
    const rawPayload = await req.json();
    const record = rawPayload.record || rawPayload;

    if (!record || !record.user_id) {
      return new Response(JSON.stringify({ error: "Missing record or user_id" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const serviceAccountRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountRaw) {
      console.warn("FIREBASE_SERVICE_ACCOUNT secret is not configured in Supabase.");
      return new Response(JSON.stringify({ message: "FCM skipped: No credentials" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const serviceAccount = JSON.parse(serviceAccountRaw);
    const projectId = serviceAccount.project_id;
    const clientEmail = serviceAccount.client_email;
    const privateKey = serviceAccount.private_key;

    // Supabase admin client
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Ambil FCM tokens untuk user ini
    const { data: tokens, error: tokenError } = await supabase
      .from("user_fcm_tokens")
      .select("token")
      .eq("user_id", record.user_id);

    if (tokenError || !tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ message: "No active device tokens found" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const accessToken = await getAccessToken(clientEmail, privateKey);

    // Tentukan judul berdasarkan tipe notifikasi
    let title = "Beres";
    if (record.type === "new_job") title = "Pesanan Jasa Baru Sekitar Anda";
    else if (record.type === "job_responded") title = "Tukang Merespon Pesanan";
    else if (record.type === "job_locked") title = "Anda Dipilih oleh Customer!";

    // Kirim notifikasi ke seluruh device user via FCM HTTP v1 API
    const sendPromises = tokens.map(async ({ token }: { token: string }) => {
      const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
      const response = await fetch(fcmUrl, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: token,
            notification: {
              title: title,
              body: record.body,
            },
            data: {
              job_id: record.job_id || "",
              type: record.type || "",
            },
          },
        }),
      });

      // Jika token expired/invalid (404/NOT_FOUND), hapus dari DB
      if (!response.ok) {
        const errJson = await response.json();
        if (
          errJson.error?.details?.some((d: any) => d.errorCode === "UNREGISTERED") ||
          errJson.error?.status === "NOT_FOUND"
        ) {
          await supabase.from("user_fcm_tokens").delete().eq("token", token);
        }
      }
      return response.status;
    });

    await Promise.all(sendPromises);

    return new Response(JSON.stringify({ success: true, count: tokens.length }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error: any) {
    console.error("Push Notification Error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
