# Jana — The Private Trust Network

Jana is a premium, privacy-first personal trust network and secure messaging app. It is designed for professionals, creators, and individuals who want a distraction-free space for their most valuable connections, completely free from social media noise, public directories, and spam.

In Jana, a **Private Trust Network** is not confined to isolated 1-on-1 pairs. Instead, your private network naturally encompasses your **1st-degree direct connections**, **2nd-degree connections (mutual friends)**, and **3rd-degree extended connections**. Because every person across these degrees enters exclusively through verified, human-to-human trusted paths—**scanning physical QR codes**, **sharing single-use VIP Pass Keys**, or **curated introductions through mutual friends**—your entire multi-degree network remains high-trust, authentic, and completely immune to cold messages and public web scraping.

---

## 1. The Core Vision: Multi-Degree Intimacy by Default

Traditional social networks expose your contact information to the public, leading to unwanted spam and scraping. Jana reverses this dynamic by redefining privacy as a **trusted web of 1st, 2nd, and 3rd degree connections**:

- **Multi-Degree Trust Graph**: Your private network spans 1st-degree (people you connected with directly), 2nd-degree (friends of your direct connections), and 3rd-degree peers. You gain access to an extended circle of trusted individuals without exposing your profile to strangers.
- **Connections by Consent**: You can only interact directly with people you have physically met, or people introduced to you through a mutual connection in your 2nd or 3rd degree graph.
- **Separation of Concerns**: Share your business details with professional contacts while keeping your social profile for personal friends, all under a single account.
- **Ultimate Data Control**: You decide exactly who sees your contact details. Hide your phone number from your network with a single tap, or share it selectively when ready.
- **Complete Sign-Out Cleanliness**: When you sign out, all local conversation history is completely cleared from the device. Your history is safely restored only when you sign back in.

---

## 2. Your Dual Digital Identity

Jana allows you to represent yourself differently depending on the context, using two distinct cards:
- **The Casual Card**: Designed for social and personal connections. It showcases your profile photo, a custom bio, and links to your Instagram or Spotify music handles.
- **The Professional Card**: Designed for business and career networking. It features your current company, job role, LinkedIn link, business email, and phone number.
- **One-Tap Privacy**: Next to your phone number on your card, a lock icon allows you to instantly toggle its visibility. When locked, your phone number displays as "Private" and is hidden from connections.

---

## 3. The Connect Hub & Interactive Network Map

The **Connect Hub** and **Your Network** view provide your cockpit for expanding and visualizing your multi-degree trust graph without public exposure:
- **Your Connection Code**: A unique, secure numeric ID associated with your profile.
- **Secure Camera Scanner**: Scan a peer's QR code in person to connect instantly as a 1st-degree contact. A smooth, secure loading screen confirms the profile details are loading safely.
- **VIP Pass Keys**: Generate a secure, single-use link code to send to someone via message or email. Once used, the key expires immediately, ensuring nobody else can use it to contact you.
- **Invite Peer Link**: Share a warm, pre-written text message to invite close peers to join your trust network.
- **Interactive Multi-Degree Network Map**: Visualize your personal trust network as an interactive 2D constellation. Inner nodes display your 1st-degree direct connections with high-resolution avatars, while outer nodes represent 2nd-degree and 3rd-degree connections linked via curved bezier paths, mutual connection indicators, atmospheric particle effects, and touch-haptic node inspection.

---

## 4. Curated Referral Pipeline (Friend-of-a-Friend Introductions)

To connect with someone in your 2nd or 3rd degree network, you request an introduction through a mutual friend:
1. **Requesting an Intro**: You visit your friend’s profile, browse their connection circle (your 2nd-degree network), and request an introduction to the person you wish to connect with.
2. **Intermediary Review**: Your mutual friend receives a notification. They can review your request, add a helpful recommendation note, and forward it.
3. **Recipient Action**: The recipient receives a notification saying: *"Friend referred You to them"*, along with the recommendation note. They can tap **Connect** to accept or **Ignore** to decline, giving them complete control over who enters their 1st-degree circle.

---

## 5. Mafias (Private Trust Circles)

Create private, custom groups called **Mafias** to communicate and collaborate within your network:
- **Invite-Only Join System**: Mafias are completely private and do not appear in any public directory. Users join exclusively via a numeric Invite Code or secure QR code scan.
- **Approval Queues**: Set your Mafia to require approval so that new members must be reviewed and approved by an Elder before entering.
- **Custom Roles and Hierarchy**: Assign roles with distinct visual colors (such as Elder, Healer, Hunter, or Member), or build your own custom roles with custom emojis and badges.
- **Visual Permissions Builder**: Elders can toggle specific access controls (such as who can invite new members, edit Mafia details, change roles, or delete the group) using a simple checkbox dashboard.
- **Interactive Group Chats**: Share text and coordinate updates inside the private Mafia chat room, featuring an integrated activity log that records system changes (like role updates or member changes) inline.

---

## 6. Event Coordination ("Plans")

Organize private gatherings and track catch-ups with your trusted circle:
- **Unified Event Feed**: View all upcoming and past meetups in a clean chronological list with status badges and real-time countdown clocks.
- **Custom Plans**: Schedule offline gatherings or online calls by specifying the date, time, location coordinates, meeting links, and custom category topics.
- **Selective Invitations**: Handpick invitees from either your Casual or Professional networks across your trusted network graph.
- **Dual Automatic Reminders**: The system automatically schedules and sends two push notification alerts—one exactly 30 minutes before the gathering starts and another at start time.

---

## 7. Premium Chat & Store-and-Forward Architecture

Enjoy private, secure messaging with connections built on a zero-server-footprint pipeline:
- **Local SQLite Database**: Conversations are stored locally on your device in SQLite, giving you instantaneous loading times and offline access.
- **Store-and-Forward Privacy**: Supabase acts solely as a temporary relay. Messages are stored transiently on the server until delivered to the recipient's device. Once received, saved to local storage, and acknowledged (`receiver_acked = true`), the message row is automatically deleted from Supabase, leaving zero server-side history.
- **Real-Time Delivery Ticks**:
  - **1 Grey Tick** (`sent`): Message reached the server.
  - **2 Grey Ticks** (`delivered`): Message landed and saved in recipient's local SQLite database.
  - **2 Blue Ticks** (`read`): Recipient opened and viewed the chat room.
- **Dynamic Feed Ordering**: When a new message arrives, the conversation automatically jumps to the top of your chat list, highlighting itself with a clean unread badge.
- **Voice Messages**: Record and share voice notes with native sound indicators that play when starting, sending, or receiving audio.
- **Unsent Message Drafts**: If you type a message and navigate away or exit the app, your draft is saved locally. A draft indicator appears in the chat list, letting you pick up right where you left off.

---

## 7. Network Feed (Private Multi-Degree Thought Feed)

Share short-form text thoughts, announcements, and discussions exclusively with your trusted network circle:
- **Multi-Degree Privacy**: Posts are visible strictly to you, your 1st-degree direct connections, and 2nd/3rd-degree extended network peers (`get_network_reach`). Zero public exposure or web indexing.
- **Unseen-First Smart Bucketing**: Loads unseen posts first. When catch-up is reached, displays a "You're all caught up ✨" divider and seamless transitions into previous seen posts.
- **Batched Dwell Seen Tracking**: Posts are marked as seen automatically when visibly rendered on screen for a dwell threshold, buffered in memory, and flushed as a single batched RPC write (`mark_posts_seen`) to eliminate network overhead.
- **Degree Affordances**:
  - **1st Degree**: Direct connection indicator.
  - **2nd Degree**: Interactive "Connect" button launching mutual friend referral requests.
  - **3rd Degree**: Soft reachability indicator without empty referral actions.
- **Flat Threads & Client-Side Parent Resolution**: Tap any post to view the full flat thread (`get_thread`). Parent "Replying to @User" labels are resolved client-side in memory for zero extra SQL queries. Soft-deleted posts display a "This post was removed" placeholder preserving thread structure.

---

## 8. Intelligent Notifications & Profile Nudges

Jana respects your time and keeps you in your flow across iOS and Android:
- **Foreground vs. Background Intelligence**: If you are actively using the app, loud system notifications are suppressed in favor of a silent, custom sliding in-app banner (`InAppNotificationBanner`). If the app is closed or backgrounded, standard system push notifications are delivered.
- **Smart Profile Completion Nudges**: Incomplete profiles trigger a persistent `ProfileNudgeBanner` showing step-by-step progress (e.g. `2/4` missing fields). Dismissing the nudge with the "X" button syncs a 2-day suppression timestamp (`profile_nudge_dismissed_at`) across all your logged-in devices.
- **Lock Screen Quick Actions**: Respond to messages or accept/decline invites directly from your device's notification drawer using quick action buttons (like **Reply**, **Mark as Read**, or **Accept**).
- **Read-Only Alerts**: System confirmation notices (like connection approvals) are displayed cleanly as text notifications without unnecessary buttons.

---

## 9. Safety, Moderation, & Blocking

Maintain complete control over your social environment:
- **Content Flagging**: Long-press any message to report inappropriate content (harassment, spam, etc.) with custom reporting reasons.
- **Severing Connections**: Disconnect from anyone at any time. Choose "Delete Connection" to silently remove them, or "Delete and Report" to submit safety concerns.
- **Complete Blocking & Isolation**: Block any contact to immediately hide their message history from your screen. Blocked users are restricted from sending you messages, requesting introductions, or connecting with you again through QR codes or VIP keys.
