import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"
import { JWT } from "npm:google-auth-library@9.0.0"

const supabaseUrl = Deno.env.get("SUPABASE_URL")!
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const serviceAccountJson = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!)

serve(async (req) => {
  try {
    const payload = await req.json()
    // The webhook payload from Supabase will contain the inserted row in payload.record
    const record = payload.record

    if (!record) {
      return new Response("No record found in payload", { status: 400 })
    }

    const { id: messageId, tribe_id: tribeId, sender_id: senderId, content: msgContent, message_type: msgType } = record

    // 1. Initialize Supabase Client with Service Role Key (bypasses RLS)
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // 2. Fetch the sender's profile name and avatar_url to display in the notification
    const { data: senderProfile } = await supabase
      .from("profiles")
      .select("name, avatar_url")
      .eq("id", senderId)
      .single()

    const senderName = senderProfile?.name || "Someone"

    // 3. Fetch the tribe's name
    const { data: tribeData } = await supabase
      .from("tribes")
      .select("name")
      .eq("id", tribeId)
      .single()

    const tribeName = tribeData?.name || "Mafia"

    // 4. Fetch the other active members in this Mafia
    const { data: members, error: mError } = await supabase
      .from("tribe_members")
      .select("user_id")
      .eq("tribe_id", tribeId)
      .eq("status", "active")
      .neq("user_id", senderId)

    if (mError || !members || members.length === 0) {
      console.log(`No active recipients found for Mafia group ${tribeId} other than sender ${senderId}`)
      return new Response("No recipients found", { status: 200 })
    }

    const recipientIds = members.map((m) => m.user_id)

    // 5. Fetch registered FCM tokens for the recipients
    const { data: tokens, error: tError } = await supabase
      .from("user_push_tokens")
      .select("fcm_token")
      .in("user_id", recipientIds)

    if (tError || !tokens || tokens.length === 0) {
      console.log("No registered push tokens found for Mafia recipients:", recipientIds)
      return new Response("No push tokens registered", { status: 200 })
    }

    // 6. Generate Google OAuth2 access token for Firebase Cloud Messaging
    const jwt = new JWT({
      email: serviceAccountJson.client_email,
      key: serviceAccountJson.private_key,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    })
    const credentials = await jwt.authorize()
    const accessToken = credentials.access_token

    // 7. Determine message text to show
    const displayBody = msgType === "image" ? "[Image]" : msgContent

    // 8. Send high-priority background notification + system notification to each device token
    const results = []
    for (const row of tokens) {
      const fcmToken = row.fcm_token

      // Generate a stable numeric notification ID from the message UUID
      const notificationId = parseInt(messageId.replace(/-/g, "").substring(0, 8), 16) & 0x7FFFFFFF

      const body = {
        message: {
          token: fcmToken,
          data: {
            action: "tribe_message",
            message_id: messageId,
            tribe_id: tribeId,
            tribe_name: tribeName,
            sender_id: String(senderId),
            sender_name: senderName,
            payload: displayBody,
            sender_avatar: senderProfile?.avatar_url || "",
            notification_id: String(notificationId),
          },
          android: {
            priority: "high",
          },
          apns: {
            headers: {
              "apns-priority": "10",
              "apns-push-type": "alert",
            },
            payload: {
              aps: {
                "content-available": 1,
                alert: {
                  title: `New Message in ${tribeName}`,
                  body: `${senderName}: ${displayBody}`,
                },
                sound: "default",
                "thread-id": tribeId,
              },
            },
          },
        },
      }

      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${serviceAccountJson.project_id}/messages:send`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify(body),
        }
      )

      const responseText = await response.text()
      results.push({
        token: fcmToken,
        ok: response.ok,
        status: response.status,
        body: responseText,
      })

      if (!response.ok) {
        console.error(`Failed to send Mafia push notification to token ${fcmToken}:`, responseText)
      } else {
        console.log(`Successfully sent Mafia push notification to token: ${fcmToken}`)
      }
    }

    return new Response(JSON.stringify({ success: true, results }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    })
  } catch (err) {
    console.error("Error processing Mafia push webhook:", err)
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    })
  }
})
