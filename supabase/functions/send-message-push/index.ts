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

    const { id: messageId, room_id: roomId, sender_id: senderId, payload: msgPayload } = record

    // 1. Initialize Supabase Client with Service Role Key (bypasses RLS)
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // 2. Fetch the sender's profile name and avatar_url to display in the notification and banner
    const { data: senderProfile } = await supabase
      .from("profiles")
      .select("name, avatar_url")
      .eq("id", senderId)
      .single()

    const senderName = senderProfile?.name || "New Message"

    // 3. Fetch the other participants in this chat room
    const { data: participants, error: pError } = await supabase
      .from("room_participants")
      .select("user_id")
      .eq("room_id", roomId)
      .neq("user_id", senderId)

    if (pError || !participants || participants.length === 0) {
      console.log(`No recipients found for room ${roomId} other than sender ${senderId}`)
      return new Response("No recipients found", { status: 200 })
    }

    const recipientIds = participants.map((p) => p.user_id)

    // 4. Fetch registered FCM tokens for the recipients
    const { data: tokens, error: tError } = await supabase
      .from("user_push_tokens")
      .select("fcm_token")
      .in("user_id", recipientIds)

    if (tError || !tokens || tokens.length === 0) {
      console.log("No registered push tokens found for recipients:", recipientIds)
      return new Response("No push tokens registered", { status: 200 })
    }

    // 5. Generate Google OAuth2 access token for Firebase Cloud Messaging
    const jwt = new JWT({
      email: serviceAccountJson.client_email,
      key: serviceAccountJson.private_key,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    })
    const credentials = await jwt.authorize()
    const accessToken = credentials.access_token

    // 6. Send high-priority background notification + system notification to each device token
    const results = []
    let anySuccess = false
    for (const row of tokens) {
      const fcmToken = row.fcm_token

      // Generate a stable numeric notification ID from the message UUID
      // Take first 8 hex chars of the UUID and convert to a 31-bit positive integer
      const notificationId = parseInt(messageId.replace(/-/g, "").substring(0, 8), 16) & 0x7FFFFFFF

      const body = {
        message: {
          token: fcmToken,
          data: {
            action: "new_message",
            message_id: messageId,
            room_id: roomId,
            sender_id: String(senderId),
            sender_name: senderName,
            payload: msgPayload,
            sender_avatar: senderProfile?.avatar_url || "",
            notification_id: String(notificationId),
          },
          android: {
            priority: "high",
          },
          apns: {
            headers: {
              "apns-priority": "10",         // 10 = immediate delivery (required for alert type)
              "apns-push-type": "alert",     // alert type so iOS treats it as a displayable notification
            },
            payload: {
              aps: {
                "content-available": 1,      // still request background execution when app is backgrounded
                alert: {
                  title: senderName,
                  body: msgPayload,          // this is the data['payload'] you already have in scope
                },
                sound: "default",
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
        console.error(`Failed to send push notification to token ${fcmToken}:`, responseText)
      } else {
        console.log(`Successfully sent push notification to token: ${fcmToken}`)
        anySuccess = true
      }
    }

    // If the push notification was successfully sent to at least one of the recipient's devices,
    // update the message status to 'delivered' in the database. This acts as the source-of-truth
    // status update for cases where the recipient's app is closed/force-killed (especially on iOS).
    if (anySuccess) {
      const { error: updateError } = await supabase
        .from("messages")
        .update({ status: "delivered" })
        .eq("id", messageId)
        .eq("status", "sent")

      if (updateError) {
        console.error(`Failed to update message ${messageId} status to 'delivered' in Edge Function:`, updateError)
      } else {
        console.log(`Successfully updated message ${messageId} status to 'delivered' via Edge Function.`)
      }
    }

    return new Response(JSON.stringify({ success: true, results }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    })
  } catch (err) {
    console.error("Error processing push webhook:", err)
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    })
  }
})