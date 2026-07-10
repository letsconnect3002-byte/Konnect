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

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    let recipientId: number
    let actorId: number
    let planId: string
    let type: string
    let notificationId: string
    let changedFields: string[] = []

    if (record.invitee_id !== undefined) {
      recipientId = Number(record.invitee_id)
      actorId = Number(record.inviter_id)
      planId = String(record.plan_id)
      type = "plan_invite"
      
      const { data: notif } = await supabase
        .from("connection_notifications")
        .select("id")
        .eq("user_id", recipientId)
        .eq("other_user_id", actorId)
        .eq("type", "plan_invite")
        .eq("note", planId)
        .maybeSingle()
        
      notificationId = notif?.id || String(record.id)
    } else {
      recipientId = Number(record.user_id)
      actorId = Number(record.other_user_id)
      type = String(record.type)
      notificationId = String(record.id)

      const rawNote = String(record.note || "")
      if (rawNote.startsWith("{")) {
        try {
          const parsed = JSON.parse(rawNote)
          planId = String(parsed.plan_id)
          changedFields = parsed.changed_fields || []
        } catch (e) {
          planId = rawNote
        }
      } else {
        planId = rawNote
      }

      if (record.is_seen === true) {
        console.log("Skipping push notification because record is already seen.")
        return new Response("Seen notification skipped", { status: 200 })
      }
    }

    if (
      type !== "plan_invite" &&
      type !== "plan_update" &&
      type !== "plan_reminder_30" &&
      type !== "plan_reminder_start"
    ) {
      return new Response("Not a plan notification, skipped", { status: 200 })
    }

    // 2. Fetch the actor's profile name and avatar
    const { data: actorProfile } = await supabase
      .from("profiles")
      .select("name, avatar_url")
      .eq("id", actorId)
      .single()

    const actorName = actorProfile?.name || "Someone"
    const actorAvatar = actorProfile?.avatar_url || ""

    // 3. Fetch the plan details
    const { data: plan } = await supabase
      .from("plans")
      .select("title, category, starts_at")
      .eq("id", planId)
      .single()

    if (!plan) {
      console.log(`Plan ${planId} not found in database. Skipping notification.`)
      return new Response("Plan not found", { status: 200 })
    }

    const planTitle = plan.title || "Untitled Plan"
    const startsAtStr = plan.starts_at
    let timeLabel = "in 30 minutes"
    if (startsAtStr) {
      try {
        const startsAt = new Date(startsAtStr)
        const diffMs = startsAt.getTime() - Date.now()
        if (diffMs > 0) {
          const totalSecs = Math.floor(diffMs / 1000)
          const secs = totalSecs % 60
          const totalMins = Math.floor(totalSecs / 60)
          const mins = totalMins % 60
          const totalHours = Math.floor(totalMins / 60)
          const hours = totalHours % 24
          const days = Math.floor(totalHours / 24)

          const pad = (num: number) => String(num).padStart(2, "0")

          if (days > 0) {
            timeLabel = `in ${days}d:${pad(hours)}h:${pad(mins)}m:${pad(secs)}s`
          } else if (hours > 0) {
            timeLabel = `in ${pad(hours)}h:${pad(mins)}m:${pad(secs)}s`
          } else {
            timeLabel = `in ${pad(mins)}m:${pad(secs)}s`
          }
        } else {
          timeLabel = "now"
        }
      } catch (e) {
        console.error("Error parsing plan starts_at on server:", e)
      }
    }

    // 4. Formulate the notification content based on the notification type
    let title = "New Plan Notification"
    let bodyText = "You have a new update."

    if (type === "plan_invite") {
      title = "New Plan Invitation"
      bodyText = `${actorName} invited you to join "${planTitle}"`
    } else if (type === "plan_update") {
      title = "Plan Updated"
      let changeDesc = ""
      if (changedFields && changedFields.length > 0) {
        const labelsMap: Record<string, string> = {
          starts_at: "time",
          location: "location",
          title: "title",
          description: "description",
          category: "category",
          plan_type: "type",
          is_online: "online status",
          meeting_link: "meeting link",
        }
        const labels = changedFields.map(f => labelsMap[f] || f)
        changeDesc = ` (changed: ${labels.join(", ")})`
      }
      bodyText = `${actorName} updated the plan "${planTitle}"${changeDesc}`
    } else if (type === "plan_reminder_30") {
      title = "Upcoming Plan Reminder"
      bodyText = `"${planTitle}" starts ${timeLabel}`
    } else if (type === "plan_reminder_start") {
      title = "Plan Starting Now"
      bodyText = `"${planTitle}" is starting now!`
    }

    let apnsCategory = "default_category"

    // 5. Fetch registered FCM tokens for the recipient
    const { data: tokens, error: tError } = await supabase
      .from("user_push_tokens")
      .select("fcm_token")
      .eq("user_id", recipientId)

    if (tError || !tokens || tokens.length === 0) {
      console.log(`No registered push tokens found for recipient user ${recipientId}`)
      return new Response("No push tokens registered", { status: 200 })
    }

    // 6. Generate Google OAuth2 access token for FCM
    const jwt = new JWT({
      email: serviceAccountJson.client_email,
      key: serviceAccountJson.private_key,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    })
    const credentials = await jwt.authorize()
    const accessToken = credentials.access_token

    // 7. Send notification to each device token
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
            plan_id: String(planId),
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

      const fcmResponse = await fetch(
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

      const fcmText = await fcmResponse.text()
      let fcmResult = {}
      try {
        fcmResult = JSON.parse(fcmText)
      } catch (e) {
        fcmResult = { error: "Failed to parse JSON response: " + fcmText }
      }
      results.push({ token: fcmToken, status: fcmResponse.status, result: fcmResult })
    }

    console.log("FCM send results:", JSON.stringify(results))

    return new Response(JSON.stringify({ success: true, sends: results }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    })
  } catch (error) {
    console.error("Error in Edge Function execution:", error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    })
  }
})
