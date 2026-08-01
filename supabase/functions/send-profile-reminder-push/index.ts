import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"
import { JWT } from "npm:google-auth-library@9.0.0"

const supabaseUrl = Deno.env.get("SUPABASE_URL")!
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const serviceAccountJson = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!)

serve(async (req) => {
  try {
    // 1. Initialize Supabase Client with Service Role Key
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Check for target_user_id in JSON body or URL query parameter
    let targetUserId: number | null = null
    try {
      const body = await req.json()
      if (body.target_user_id) targetUserId = Number(body.target_user_id)
      if (body.user_id) targetUserId = Number(body.user_id)
    } catch (_) {
      const url = new URL(req.url)
      const qp = url.searchParams.get("target_user_id") || url.searchParams.get("user_id")
      if (qp) targetUserId = Number(qp)
    }

    let userIds: number[] = []

    if (targetUserId) {
      console.log(`Targeting single user account for testing: user_id=${targetUserId}`)
      userIds = [targetUserId]
    } else {
      // 2. Automated daily schedule query
      const twoDaysAgo = new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString()

      const { data: incompleteProfiles, error: pError } = await supabase
        .from("profiles")
        .select("id, name, avatar_url, profession, company, profile_nudge_dismissed_at")
        .lt("created_at", twoDaysAgo)
        .or(`profile_nudge_dismissed_at.is.null,profile_nudge_dismissed_at.lt.${twoDaysAgo}`)
        .or("avatar_url.is.null,avatar_url.eq.,profession.is.null,profession.eq.")

      if (pError || !incompleteProfiles || incompleteProfiles.length === 0) {
        console.log("No incomplete profiles found for reminder push.")
        return new Response(JSON.stringify({ message: "No incomplete profiles found" }), {
          headers: { "Content-Type": "application/json" },
          status: 200,
        })
      }

      userIds = incompleteProfiles.map((p) => p.id)
    }

    // 3. Fetch registered FCM tokens for these users
    const { data: tokens, error: tError } = await supabase
      .from("user_push_tokens")
      .select("user_id, fcm_token")
      .in("user_id", userIds)

    if (tError || !tokens || tokens.length === 0) {
      console.log("No registered push tokens found for incomplete profile users.")
      return new Response(JSON.stringify({ message: "No push tokens found" }), {
        headers: { "Content-Type": "application/json" },
        status: 200,
      })
    }

    // 4. Generate Google OAuth2 access token for FCM
    const jwt = new JWT({
      email: serviceAccountJson.client_email,
      key: serviceAccountJson.private_key,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    })
    const credentials = await jwt.authorize()
    const accessToken = credentials.access_token

    // 5. Send FCM system push notifications to each device token
    const results = []
    for (const row of tokens) {
      const fcmToken = row.fcm_token

      const fcmBody = {
        message: {
          token: fcmToken,
          notification: {
            title: "Complete your profile ✨",
            body: "Your profile is almost complete! Tap to add your photo & headline 👀",
          },
          data: {
            action: "complete_profile",
            title: "Complete your profile ✨",
            body: "Your profile is almost complete! Tap to add your photo & headline 👀",
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
                  title: "Complete your profile ✨",
                  body: "Your profile is almost complete! Tap to add your photo & headline 👀",
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
        console.error(`Failed to send profile reminder push to token ${fcmToken}:`, responseText)
      } else {
        console.log(`Successfully sent profile reminder push to token: ${fcmToken}`)
      }
    }

    return new Response(JSON.stringify({ success: true, count: results.length, results }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    })
  } catch (err) {
    console.error("Error processing profile reminder push:", err)
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    })
  }
})
