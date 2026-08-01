import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"
import { JWT } from "npm:google-auth-library@9.0.0"

const supabaseUrl = Deno.env.get("SUPABASE_URL")!
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const serviceAccountJson = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!)

function getEmojiForIcon(iconName: string): string {
  switch (iconName) {
    case "briefcase": return "💼"
    case "coffee": return "☕"
    case "flight": return "✈️"
    case "fitness_center": return "🏋️"
    case "school": return "🎓"
    case "groups": return "👥"
    case "chat": return "💬"
    case "person_add": return "🙋"
    case "rate_review": return "📝"
    case "work": return "💼"
    case "help": return "ℹ️"
    case "handshake": return "🤝"
    case "hub": return "🌐"
    default: return "✨"
  }
}

serve(async (req) => {
  try {
    const payload = await req.json()
    const record = payload.record

    if (!record) {
      return new Response("No record found in payload", { status: 400 })
    }

    const { id: pulseId, user_id: publisherId, pulse_tag_id: tagId, text, visibility } = record

    if (!publisherId || !pulseId) {
      return new Response("Missing required pulse parameters", { status: 400 })
    }

    // Small delay to ensure transaction writes for pulse_hidden_users complete
    await new Promise((resolve) => setTimeout(resolve, 350))

    // 1. Initialize Supabase Client with Service Role Key
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // 2. Fetch publisher profile
    const { data: publisherProfile } = await supabase
      .from("profiles")
      .select("name, avatar_url")
      .eq("id", publisherId)
      .single()

    const publisherName = publisherProfile?.name || "Someone"

    // 3. Fetch tag information
    let tagName = "Pulse"
    let tagEmoji = "✨"
    if (tagId) {
      const { data: tagData } = await supabase
        .from("pulse_tags")
        .select("name, icon")
        .eq("id", tagId)
        .single()
      if (tagData) {
        tagName = tagData.name || "Pulse"
        tagEmoji = getEmojiForIcon(tagData.icon || "")
      }
    }

    // Engaging title & call to action body (hides pulse content to drive clicks)
    const notificationTitle = `${publisherName}`
    const notificationBody = `Just shared a new pulse! Tap to see what they're up to 👀`

    // 4. Fetch excluded user IDs for this pulse
    const { data: hiddenUserRows } = await supabase
      .from("pulse_hidden_users")
      .select("hidden_user_id")
      .eq("pulse_id", pulseId)

    const hiddenUserIds = new Set<number>(
      (hiddenUserRows || []).map((h) => Number(h.hidden_user_id))
    )

    // 5. Fetch blocked user IDs for the publisher
    const { data: blockedRows } = await supabase
      .from("blocked_users")
      .select("blocker_id, blocked_id")
      .or(`blocker_id.eq.${publisherId},blocked_id.eq.${publisherId}`)

    const blockedUserIds = new Set<number>()
    if (blockedRows) {
      for (const b of blockedRows) {
        if (Number(b.blocker_id) === publisherId) {
          blockedUserIds.add(Number(b.blocked_id))
        } else {
          blockedUserIds.add(Number(b.blocker_id))
        }
      }
    }

    // 6. Fetch connections for the publisher
    const { data: connections, error: connError } = await supabase
      .from("user_connections")
      .select("user_id_1, user_id_2, user_1_shared_card, user_2_shared_card")
      .or(`user_id_1.eq.${publisherId},user_id_2.eq.${publisherId}`)

    if (connError || !connections || connections.length === 0) {
      console.log(`No connections found for publisher ${publisherId}`)
      return new Response("No connections found", { status: 200 })
    }

    // Filter eligible connections based on visibility & exclusion rules
    const pulseVisibility = (visibility || "both").toLowerCase()
    const eligibleRecipientIds: number[] = []

    for (const conn of connections) {
      const u1 = Number(conn.user_id_1)
      const u2 = Number(conn.user_id_2)
      const recipientId = u1 === publisherId ? u2 : u1

      // Rule A: Check if explicitly hidden / excluded
      if (hiddenUserIds.has(recipientId)) {
        console.log(`Skipping push to user ${recipientId} (excluded in pulse_hidden_users)`)
        continue
      }

      // Rule B: Check if blocked
      if (blockedUserIds.has(recipientId)) {
        console.log(`Skipping push to user ${recipientId} (blocked user)`)
        continue
      }

      // Rule C: Visibility check against shared card type
      const sharedCard = (
        u1 === publisherId ? conn.user_2_shared_card : conn.user_1_shared_card
      || "both").toLowerCase()

      let isAllowed = false
      if (pulseVisibility === "both") {
        isAllowed = true
      } else if (pulseVisibility === "casual") {
        isAllowed = sharedCard === "casual" || sharedCard === "both"
      } else if (pulseVisibility === "professional") {
        isAllowed = sharedCard === "professional" || sharedCard === "both"
      }

      if (isAllowed) {
        eligibleRecipientIds.push(recipientId)
      } else {
        console.log(`Skipping push to user ${recipientId} (visibility mismatch: pulse=${pulseVisibility}, sharedCard=${sharedCard})`)
      }
    }

    if (eligibleRecipientIds.length === 0) {
      console.log(`No eligible recipients for pulse ${pulseId}`)
      return new Response("No eligible recipients", { status: 200 })
    }

    // 7. Fetch FCM push tokens for eligible recipients
    const { data: tokens, error: tError } = await supabase
      .from("user_push_tokens")
      .select("fcm_token")
      .in("user_id", eligibleRecipientIds)

    if (tError || !tokens || tokens.length === 0) {
      console.log("No registered push tokens found for eligible recipients:", eligibleRecipientIds)
      return new Response("No push tokens registered for eligible recipients", { status: 200 })
    }

    // 8. Generate Google OAuth2 access token for FCM
    const jwt = new JWT({
      email: serviceAccountJson.client_email,
      key: serviceAccountJson.private_key,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    })
    const credentials = await jwt.authorize()
    const accessToken = credentials.access_token

    // 9. Send proper FCM system notifications (with top-level notification payload)
    const noteText = text ? String(text).trim() : ""
    const results = []
    for (const row of tokens) {
      const fcmToken = row.fcm_token

      const fcmBody = {
        message: {
          token: fcmToken,
          notification: {
            title: notificationTitle,
            body: notificationBody,
          },
          data: {
            action: "new_pulse",
            pulse_id: String(pulseId),
            publisher_id: String(publisherId),
            publisher_name: publisherName,
            publisher_avatar: publisherProfile?.avatar_url || "",
            tag_name: tagName,
            tag_emoji: tagEmoji,
            text: noteText,
            visibility: pulseVisibility,
          },
          android: {
            priority: "high",
            notification: {
              sound: "default",
              channelId: "high_importance_channel",
            },
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
                  title: notificationTitle,
                  body: notificationBody,
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
        console.error(`Failed to send pulse push notification to token ${fcmToken}:`, responseText)
      } else {
        console.log(`Successfully sent pulse push notification to token: ${fcmToken}`)
      }
    }

    return new Response(JSON.stringify({ success: true, count: results.length, results }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    })
  } catch (err) {
    console.error("Error processing pulse push notification webhook:", err)
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    })
  }
})
