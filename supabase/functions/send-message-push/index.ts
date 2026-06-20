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

    // 2. Fetch the sender's profile name to display in the notification title
    const { data: senderProfile } = await supabase
      .from("profiles")
      .select("name")
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

    // 4. Fetch registered FCM tokens for the recipients (including user_id)
    const { data: tokens, error: tError } = await supabase
      .from("user_push_tokens")
      .select("user_id, fcm_token")
      .in("user_id", recipientIds)

    if (tError || !tokens || tokens.length === 0) {
      console.log("No registered push tokens found for recipients:", recipientIds)
      return new Response("No push tokens registered", { status: 200 })
    }

    // Fetch Monk Mode settings from profiles table
    const { data: recipientProfiles, error: rpError } = await supabase
      .from("profiles")
      .select("id, monk_mode_enabled, monk_mode_deactivate_at, monk_mode_blocked_ids")
      .in("id", recipientIds)

    if (rpError) {
      console.error("Error fetching recipient profiles for Monk Mode check:", rpError)
    }

    // Build a map of Monk Mode status per recipient
    const recipientMonkModeMap = new Map<number, {
      enabled: boolean;
      deactivateAt: string | null;
      blockedIds: number[];
    }>()

    if (recipientProfiles) {
      for (const prof of recipientProfiles) {
        recipientMonkModeMap.set(prof.id, {
          enabled: !!prof.monk_mode_enabled,
          deactivateAt: prof.monk_mode_deactivate_at || null,
          blockedIds: prof.monk_mode_blocked_ids || [],
        })
      }
    }

    const isMuted = (recipientId: number): boolean => {
      const settings = recipientMonkModeMap.get(recipientId)
      if (!settings) return false
      if (!settings.enabled) return false

      if (settings.deactivateAt) {
        const deactivateTime = new Date(settings.deactivateAt).getTime()
        if (Date.now() > deactivateTime) {
          return false // Monk mode has expired
        }
      }

      const numSenderId = Number(senderId)
      return settings.blockedIds.map(Number).includes(numSenderId)
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
    for (const row of tokens) {
      const fcmToken = row.fcm_token
      const recipientId = row.user_id

      // Generate a stable numeric notification ID from the message UUID
      // Take first 8 hex chars of the UUID and convert to a 31-bit positive integer
      const notificationId = parseInt(messageId.replace(/-/g, "").substring(0, 8), 16) & 0x7FFFFFFF

      const muted = isMuted(recipientId)

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
            notification_id: String(notificationId),
          },
          android: {
            priority: "high",
          },
          apns: {
            headers: {
              "apns-priority": muted ? "5" : "10",
              "apns-push-type": muted ? "background" : "alert",
            },
            payload: {
              aps: {
                "content-available": 1,
                ...(!muted && {
                  alert: {
                    title: senderName,
                    body: msgPayload,
                  },
                  sound: "default",
                }),
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