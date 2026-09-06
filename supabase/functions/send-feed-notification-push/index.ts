import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"
import { JWT } from "npm:google-auth-library@9.0.0"

const supabaseUrl = Deno.env.get("SUPABASE_URL")!
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const serviceAccountJson = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!)

serve(async (req) => {
  try {
    const payload = await req.json()
    const record = payload.record

    if (!record) {
      return new Response("No record found in payload", { status: 400 })
    }

    const {
      id: notificationId,
      user_id: recipientId,
      other_user_id: actorId,
      type,
      note,
      is_seen,
    } = record

    // Skip push notifications for already seen notifications
    if (is_seen === true) {
      console.log("Skipping feed push notification because record is already seen.")
      return new Response("Seen notification skipped", { status: 200 })
    }

    let realType = type
    let postId = ""
    let rootPostId = ""
    let parentAuthorName = "a post"
    let isAnonymous = false
    let explicitActorName = ""

    if (note && note.startsWith("{")) {
      try {
        const parsed = JSON.parse(note)
        if (parsed.real_type) realType = parsed.real_type
        if (parsed.post_id) postId = String(parsed.post_id)
        if (parsed.root_post_id) rootPostId = String(parsed.root_post_id)
        if (parsed.parent_author_name) parentAuthorName = String(parsed.parent_author_name)
        if (parsed.is_anonymous === true || parsed.is_anonymous === "true") isAnonymous = true
        if (parsed.actor_name) explicitActorName = String(parsed.actor_name)
      } catch (e) {
        console.error("Error parsing feed notification note JSON:", e)
      }
    }

    // Only process feed notification types
    const validFeedTypes = ["feed_reply", "feed_mention", "feed_reply_mention", "feed_post", "feed_connection_reply"]
    if (!validFeedTypes.includes(type) && !validFeedTypes.includes(realType)) {
      return new Response("Not a feed notification type, skipped", { status: 200 })
    }

    // 1. Initialize Supabase Client with Service Role Key
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Double check post anonymity from DB if not already marked
    if (!isAnonymous && postId) {
      try {
        const { data: postData } = await supabase
          .from("posts")
          .select("is_anonymous")
          .eq("id", postId)
          .single()
        if (postData?.is_anonymous) {
          isAnonymous = true
        }
      } catch (e) {
        console.error("Error checking post anonymity from DB:", e)
      }
    }

    // 2. Fetch actor profile name, avatar & anon_name
    const { data: actorProfile } = await supabase
      .from("profiles")
      .select("name, avatar_url, anon_name")
      .eq("id", actorId)
      .single()

    let actorName = actorProfile?.name || "Someone"
    let actorAvatar = actorProfile?.avatar_url || ""

    if (isAnonymous) {
      actorName = explicitActorName || actorProfile?.anon_name || "Anonymous"
      actorAvatar = ""
    }

    // 3. Formulate push title & body (NEVER send post content)
    let title = isAnonymous ? "Anonymous Feed Update" : "Network Feed Update"
    let bodyText = `${actorName} updated the network feed.`

    if (realType === "feed_reply_mention") {
      title = isAnonymous ? "New Anonymous Reply & Mention" : "New Reply & Mention"
      bodyText = `${actorName} replied to your post and mentioned you on their post.`
    } else if (realType === "feed_reply") {
      title = isAnonymous ? "New Anonymous Reply" : "New Reply"
      bodyText = `${actorName} replied to your post.`
    } else if (realType === "feed_mention") {
      title = isAnonymous ? "New Anonymous Mention" : "New Mention"
      bodyText = `${actorName} mentioned you on their post.`
    } else if (realType === "feed_post") {
      title = isAnonymous ? "New Anonymous Post" : "New Post"
      bodyText = `${actorName} has uploaded a post, tap to see`
    } else if (realType == "feed_connection_reply") {
      if (postId) {
        try {
          const { data: currentPost } = await supabase
            .from("posts")
            .select("reply_to_post_id")
            .eq("id", postId)
            .single()
          if (currentPost?.reply_to_post_id) {
            const { data: parentPost } = await supabase
              .from("posts")
              .select("is_anonymous, author:profiles!author_id(name, anon_name)")
              .eq("id", currentPost.reply_to_post_id)
              .single()
            if (parentPost?.is_anonymous) {
              parentAuthorName = (parentPost.author as any)?.anon_name || "Anonymous"
            }
          }
        } catch (e) {
          console.error("Error double-checking parent post anonymity for feed_connection_reply:", e)
        }
      }
      title = `${actorName} joined a conversation`
      bodyText = `${actorName} replied to ${parentAuthorName}, tap to join the conversation.`
    }

    // 4. Fetch recipient FCM tokens
    const { data: tokens, error: tError } = await supabase
      .from("user_push_tokens")
      .select("fcm_token")
      .eq("user_id", recipientId)

    if (tError || !tokens || tokens.length === 0) {
      console.log(`No registered push tokens found for user ${recipientId}`)
      return new Response("No push tokens registered", { status: 200 })
    }

    // 5. Generate Google OAuth2 access token for FCM
    const jwt = new JWT({
      email: serviceAccountJson.client_email,
      key: serviceAccountJson.private_key,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    })
    const credentials = await jwt.authorize()
    const accessToken = credentials.access_token

    // 6. Send push notification to each registered device
    const results = []
    for (const row of tokens) {
      const fcmToken = row.fcm_token

      const fcmBody = {
        message: {
          token: fcmToken,
          notification: {
            title: title,
            body: bodyText,
          },
          data: {
            action: "feed_notification",
            notification_id: String(notificationId),
            type: String(realType),
            actor_id: String(actorId),
            actor_name: actorName,
            actor_avatar: actorAvatar,
            is_anonymous: isAnonymous ? "true" : "false",
            post_id: postId,
            root_post_id: rootPostId,
            title: title,
            body: bodyText,
          },
          android: {
            priority: "high",
            notification: {
              title: title,
              body: bodyText,
              channel_id: "connections_channel",
              sound: "default",
              default_sound: true,
              default_vibrate_timings: true,
              notification_priority: "PRIORITY_MAX",
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
                  title: title,
                  body: bodyText,
                },
                sound: "default",
                category: "feed_notification_category",
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
        console.error(`Failed to send feed push to ${fcmToken}:`, responseText)
      } else {
        console.log(`Successfully sent feed push to token: ${fcmToken}`)
      }
    }

    return new Response(JSON.stringify({ success: true, results }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    })
  } catch (err: any) {
    console.error("Error processing feed notification push:", err)
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    })
  }
})
