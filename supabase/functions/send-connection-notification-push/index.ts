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

    const {
      id: notificationId,
      user_id: recipientId,
      other_user_id: actorId,
      referred_user_id: targetId,
      type,
      note,
    } = record

    // Skip push notifications for already seen/actioned notifications
    if (record.is_seen === true) {
      console.log("Skipping push notification because record is already seen.")
      return new Response("Seen notification skipped", { status: 200 })
    }

    // Skip QR Code connection notifications as requested by user
    if (type === "qr_code") {
      console.log("Skipping push notification for QR code connection.")
      return new Response("QR code connection notification skipped", { status: 200 })
    }

    // 1. Initialize Supabase Client with Service Role Key
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // 2. Fetch the actor's profile name and avatar
    const { data: actorProfile } = await supabase
      .from("profiles")
      .select("name, avatar_url")
      .eq("id", actorId)
      .single()

    const actorName = actorProfile?.name || "Someone"
    const actorAvatar = actorProfile?.avatar_url || ""

    // 3. Fetch the target's profile name (if this is a referral event)
    let targetName = "Someone"
    if (targetId) {
      const { data: targetProfile } = await supabase
        .from("profiles")
        .select("name")
        .eq("id", targetId)
        .single()
      if (targetProfile?.name) {
        targetName = targetProfile.name
      }
    }

    // 4. Formulate the notification content based on the notification type
    let title = "New Notification"
    let bodyText = "You have a new update."
    let realType = type
    let tribeName = "a Mafia"
    let tribeMessage = ""

    if (note && note.startsWith("{")) {
      try {
        const parsed = JSON.parse(note)
        if (parsed.real_type) {
          realType = parsed.real_type
        }
        if (parsed.tribe_name) {
          tribeName = parsed.tribe_name
        }
        if (parsed.message) {
          tribeMessage = parsed.message
        }
      } catch (e) {
        console.error("Error parsing JSON note:", e)
      }
    }

    if (realType === "tribe_invite") {
      title = "Mafia Invitation"
      bodyText = `${actorName} invited you to join "${tribeName}"`
    } else if (realType === "tribe_request") {
      title = "Mafia Request"
      bodyText = `${actorName} requested to join "${tribeName}"`
    } else if (realType === "tribe_approved") {
      title = "Mafia Approved"
      bodyText = `Your request to join "${tribeName}" was approved`
    } else if (realType === "tribe_message") {
      title = `New Message in ${tribeName}`
      bodyText = `${actorName}: ${tribeMessage}`
    } else if (type === "vip_pass_key") {
      title = "New Connection"
      bodyText = `${actorName} connected via Private Key`
    } else if (type === "referral_connect") {
      title = "New Connection"
      bodyText = `${actorName} connected via Referral`
    } else if (type === "referral") {
      const isRequest = note && (note.startsWith("[REFERRAL_REQUEST]") || note.startsWith("[REFERRAL_REQUEST_ACTIONED]"))
      if (isRequest) {
        title = "Introduction Request"
        bodyText = `${actorName} asked to be introduced to ${targetName}`
      } else {
        title = "New Referral"
        bodyText = `${actorName} referred ${targetName} to you`
      }
    } else {
      // Fallback for other potential types
      title = "New Connection"
      bodyText = `${actorName} connected with you`
    }

    // 5. Query user connection status if it is a normal referral
    let isAlreadyConnected = false
    if (type === "referral" && targetId) {
      const isRequest = note && (note.startsWith("[REFERRAL_REQUEST]") || note.startsWith("[REFERRAL_REQUEST_ACTIONED]"))
      if (!isRequest && realType === type) {
        const id1 = recipientId < targetId ? recipientId : targetId
        const id2 = recipientId > targetId ? recipientId : targetId
        const { data: conn } = await supabase
          .from("user_connections")
          .select("user_id_1")
          .eq("user_id_1", id1)
          .eq("user_id_2", id2)
          .maybeSingle()
        isAlreadyConnected = conn !== null
      }
    }

    let apnsCategory = "default_category"
    if (realType === "tribe_invite") {
      apnsCategory = "tribe_invite_category"
    } else if (realType === "tribe_request") {
      apnsCategory = "tribe_request_category"
    } else if (type === "referral") {
      const isRequest = note && (note.startsWith("[REFERRAL_REQUEST]") || note.startsWith("[REFERRAL_REQUEST_ACTIONED]"))
      if (isRequest) {
        apnsCategory = note.startsWith("[REFERRAL_REQUEST_ACTIONED]") ? "default_category" : "referral_request_category"
      } else {
        apnsCategory = isAlreadyConnected ? "referral_message_category" : "referral_connect_category"
      }
    } else if (type === "vip_pass_key" || type === "referral_connect") {
      apnsCategory = "default_category"
    } else {
      apnsCategory = "connection_accept_category"
    }

    // 6. Fetch registered FCM tokens for the recipient
    const { data: tokens, error: tError } = await supabase
      .from("user_push_tokens")
      .select("fcm_token")
      .eq("user_id", recipientId)

    if (tError || !tokens || tokens.length === 0) {
      console.log(`No registered push tokens found for recipient user ${recipientId}`)
      return new Response("No push tokens registered", { status: 200 })
    }

    // 7. Generate Google OAuth2 access token for FCM
    const jwt = new JWT({
      email: serviceAccountJson.client_email,
      key: serviceAccountJson.private_key,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    })
    const credentials = await jwt.authorize()
    const accessToken = credentials.access_token

    // 8. Send notification to each device token
    const results = []
    for (const row of tokens) {
      const fcmToken = row.fcm_token

      const fcmBody = {
        message: {
          token: fcmToken,
          data: {
            action: "connection_notification",
            notification_id: String(notificationId),
            type: String(type),
            actor_id: String(actorId),
            actor_name: actorName,
            actor_avatar: actorAvatar,
            title: title,
            body: bodyText,
            note: note ? String(note) : "",
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
                  title: title,
                  body: bodyText,
                },
                sound: "default",
                category: apnsCategory,
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
          body: JSON.stringify(fcmBody),
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
        console.error(`Failed to send connection push to token ${fcmToken}:`, responseText)
      } else {
        console.log(`Successfully sent connection push to token: ${fcmToken}`)
      }
    }

    return new Response(JSON.stringify({ success: true, results }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    })
  } catch (err) {
    console.error("Error processing connection notification push webhook:", err)
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    })
  }
})
