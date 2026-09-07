import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const supabaseUrl = Deno.env.get("SUPABASE_URL")!
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_ANON_KEY")!

interface ExperienceItem {
  id: string
  company: string
  companyUrl?: string
  role: string
  location?: string
  startDate?: string
  endDate?: string
  isCurrent?: boolean
  description?: string
}

interface EducationItem {
  id: string
  school: string
  degree?: string
  fieldOfStudy?: string
  startYear?: string
  endYear?: string
  description?: string
}

function escapeHtml(str: string = ""): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;")
}

function getFaviconUrl(url?: string): string {
  if (!url) return ""
  try {
    const raw = url.startsWith("http") ? url : `https://${url}`
    const parsed = new URL(raw)
    const host = parsed.hostname.replace(/^www\./, "")
    return `https://www.google.com/s2/favicons?domain=${host}&sz=128`
  } catch {
    return ""
  }
}

serve(async (req: Request) => {
  const url = new URL(req.url)

  // Extract user identifier from pathname or search params (?id=...)
  let idParam = url.searchParams.get("id") || url.searchParams.get("user_id")
  if (!idParam) {
    const segments = url.pathname.split("/").filter(Boolean)
    const last = segments[segments.length - 1]
    if (last && last !== "view-profile-web") {
      idParam = last
    }
  }

  if (!idParam) {
    return new Response(
      `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Mandala | Profile Not Found</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { background: #0B0B0F; color: #fff; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; text-align: center; }
    .box { padding: 32px; background: #14141E; border-radius: 20px; border: 1px solid rgba(255,255,255,0.08); max-width: 400px; }
    h1 { font-size: 24px; margin-bottom: 8px; color: #F43F5E; }
    p { color: #94A3B8; font-size: 15px; margin-bottom: 24px; }
    a { display: inline-block; background: #6366F1; color: #fff; text-decoration: none; padding: 10px 20px; border-radius: 12px; font-weight: 600; }
  </style>
</head>
<body>
  <div class="box">
    <h1>Profile ID Missing</h1>
    <p>Please specify a valid user identifier in the URL (e.g. joinmandala.in/&lt;user_id&gt;).</p>
    <a href="https://joinmandala.in">Back to Mandala</a>
  </div>
</body>
</html>`,
      { status: 400, headers: { "Content-Type": "text/html; charset=utf-8" } }
    )
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey)

  // Query profile by numeric ID or UUID
  let query = supabase.from("profiles").select("*")
  const isNumeric = /^\d+$/.test(idParam)
  if (isNumeric) {
    query = query.eq("id", parseInt(idParam, 10))
  } else {
    query = query.or(`user_id.eq.${idParam},id.eq.${idParam}`)
  }

  const { data: profile, error } = await query.maybeSingle()

  if (error || !profile) {
    return new Response(
      `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Mandala | Profile Not Found</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { background: #0B0B0F; color: #fff; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; text-align: center; }
    .box { padding: 36px 28px; background: #14141E; border-radius: 24px; border: 1px solid rgba(255,255,255,0.08); max-width: 420px; }
    h1 { font-size: 26px; margin-bottom: 10px; color: #F87171; }
    p { color: #94A3B8; font-size: 15px; margin-bottom: 24px; line-height: 1.5; }
    a { display: inline-block; background: #6366F1; color: #fff; text-decoration: none; padding: 12px 24px; border-radius: 14px; font-weight: 600; }
  </style>
</head>
<body>
  <div class="box">
    <h1>Member Not Found</h1>
    <p>This profile does not exist or may have been deactivated.</p>
    <a href="https://joinmandala.in">Discover Mandala</a>
  </div>
</body>
</html>`,
      { status: 404, headers: { "Content-Type": "text/html; charset=utf-8" } }
    )
  }

  // Parse fields
  const name = profile.name || "Mandala Member"
  const profession = profile.profession || ""
  const company = profile.company || ""
  const headline = [profession, company].filter(Boolean).join(" at ")
  const bio = profile.professional_bio || profile.bio || ""
  const avatarUrl = profile.avatar_url || ""
  const vibeTag = profile.vibe_tag || ""

  let experience: ExperienceItem[] = []
  if (profile.experience) {
    try {
      experience = typeof profile.experience === "string" ? JSON.parse(profile.experience) : profile.experience
    } catch {
      experience = []
    }
  }

  let education: EducationItem[] = []
  if (profile.education) {
    try {
      education = typeof profile.education === "string" ? JSON.parse(profile.education) : profile.education
    } catch {
      education = []
    }
  }

  let skills: string[] = []
  if (profile.skills) {
    try {
      skills = typeof profile.skills === "string" ? JSON.parse(profile.skills) : profile.skills
    } catch {
      skills = []
    }
  }

  const ogTitle = `${name} | Interactive Resume on Mandala`
  const ogDesc = headline ? `${headline}. ${bio}`.slice(0, 160) : (bio || `View ${name}'s verified professional resume on Mandala.`)

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(ogTitle)}</title>

  <!-- Open Graph / Meta -->
  <meta property="og:title" content="${escapeHtml(ogTitle)}" />
  <meta property="og:description" content="${escapeHtml(ogDesc)}" />
  ${avatarUrl ? `<meta property="og:image" content="${escapeHtml(avatarUrl)}" />` : ""}
  <meta property="og:type" content="profile" />
  <meta property="og:site_name" content="Mandala" />

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${escapeHtml(ogTitle)}" />
  <meta name="twitter:description" content="${escapeHtml(ogDesc)}" />
  ${avatarUrl ? `<meta name="twitter:image" content="${escapeHtml(avatarUrl)}" />` : ""}

  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">

  <style>
    :root {
      --bg: #09090D;
      --card-bg: #12121A;
      --card-border: rgba(255, 255, 255, 0.08);
      --accent: #6366F1;
      --accent-glow: rgba(99, 102, 241, 0.18);
      --text-main: #FFFFFF;
      --text-sub: #94A3B8;
      --text-muted: #64748B;
      --radius: 20px;
    }

    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: var(--bg);
      color: var(--text-main);
      font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 32px 16px 60px 16px;
      -webkit-font-smoothing: antialiased;
    }

    .container {
      width: 100%;
      max-width: 680px;
      display: flex;
      flex-direction: column;
      gap: 24px;
    }

    /* Top Brand Bar */
    .brand-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 4px;
    }
    .brand-logo {
      display: flex;
      align-items: center;
      gap: 10px;
      text-decoration: none;
      color: #fff;
      font-weight: 800;
      font-size: 18px;
      letter-spacing: -0.5px;
    }
    .brand-icon {
      width: 28px;
      height: 28px;
      background: linear-gradient(135deg, #6366F1, #A855F7);
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 14px;
      font-weight: bold;
    }
    .cta-btn {
      background: rgba(255, 255, 255, 0.07);
      border: 1px solid rgba(255, 255, 255, 0.12);
      color: #fff;
      padding: 7px 15px;
      border-radius: 999px;
      font-size: 13px;
      font-weight: 600;
      text-decoration: none;
      transition: all 0.2s ease;
    }
    .cta-btn:hover {
      background: rgba(255, 255, 255, 0.14);
      border-color: rgba(255, 255, 255, 0.25);
    }

    /* Hero Profile Card */
    .profile-hero {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: var(--radius);
      padding: 32px 28px;
      position: relative;
      overflow: hidden;
      box-shadow: 0 16px 40px -12px rgba(0,0,0,0.6);
    }
    .hero-glow {
      position: absolute;
      top: -80px;
      right: -80px;
      width: 240px;
      height: 240px;
      background: radial-gradient(circle, var(--accent-glow) 0%, rgba(99,102,241,0) 70%);
      pointer-events: none;
    }
    .avatar-wrapper {
      width: 88px;
      height: 88px;
      border-radius: 50%;
      padding: 3px;
      background: linear-gradient(135deg, #6366F1, #EC4899);
      display: inline-block;
      margin-bottom: 20px;
    }
    .avatar {
      width: 100%;
      height: 100%;
      border-radius: 50%;
      object-fit: cover;
      background: #1E1E2C;
      display: block;
    }
    .avatar-placeholder {
      width: 100%;
      height: 100%;
      border-radius: 50%;
      background: #1E1E2C;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 32px;
      font-weight: 700;
      color: #A5B4FC;
    }
    .user-name {
      font-size: 26px;
      font-weight: 800;
      letter-spacing: -0.5px;
      margin-bottom: 6px;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .headline {
      font-size: 16px;
      color: #A5B4FC;
      font-weight: 600;
      margin-bottom: 12px;
    }
    .vibe-chip {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: rgba(99, 102, 241, 0.12);
      border: 1px solid rgba(99, 102, 241, 0.25);
      color: #C7D2FE;
      padding: 4px 12px;
      border-radius: 999px;
      font-size: 12px;
      font-weight: 600;
      margin-bottom: 16px;
    }
    .bio {
      color: var(--text-sub);
      font-size: 14.5px;
      line-height: 1.6;
    }

    /* Section Card */
    .section-card {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: var(--radius);
      padding: 28px;
      box-shadow: 0 10px 30px -10px rgba(0,0,0,0.5);
    }
    .section-title {
      font-size: 12.5px;
      font-weight: 700;
      letter-spacing: 1.5px;
      text-transform: uppercase;
      color: var(--text-muted);
      margin-bottom: 24px;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .section-title::after {
      content: "";
      flex: 1;
      height: 1px;
      background: rgba(255, 255, 255, 0.06);
    }

    /* Timeline */
    .timeline {
      display: flex;
      flex-direction: column;
      gap: 26px;
      position: relative;
    }
    .timeline-item {
      display: flex;
      gap: 16px;
      position: relative;
    }
    .timeline-connector {
      display: flex;
      flex-direction: column;
      align-items: center;
      flex-shrink: 0;
    }
    .company-logo {
      width: 44px;
      height: 44px;
      border-radius: 12px;
      background: #1C1C29;
      border: 1px solid rgba(255, 255, 255, 0.08);
      display: flex;
      align-items: center;
      justify-content: center;
      overflow: hidden;
      flex-shrink: 0;
    }
    .company-logo img {
      width: 28px;
      height: 28px;
      object-fit: contain;
    }
    .company-logo .fallback-icon {
      font-size: 18px;
      font-weight: 700;
      color: #A5B4FC;
    }
    .timeline-line {
      width: 2px;
      flex: 1;
      background: rgba(255, 255, 255, 0.08);
      margin-top: 10px;
      border-radius: 1px;
    }
    .timeline-item:last-child .timeline-line {
      display: none;
    }
    .timeline-content {
      flex: 1;
      padding-top: 2px;
    }
    .role-title {
      font-size: 16px;
      font-weight: 700;
      color: #fff;
      margin-bottom: 3px;
    }
    .company-row {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 14px;
      color: #CBD5E1;
      font-weight: 500;
      margin-bottom: 6px;
    }
    .company-link {
      color: #818CF8;
      text-decoration: none;
      display: inline-flex;
      align-items: center;
      gap: 4px;
      transition: color 0.2s;
    }
    .company-link:hover {
      color: #A5B4FC;
      text-decoration: underline;
    }
    .date-row {
      font-size: 12.5px;
      color: var(--text-muted);
      margin-bottom: 10px;
    }
    .current-badge {
      background: rgba(16, 185, 129, 0.15);
      border: 1px solid rgba(16, 185, 129, 0.3);
      color: #34D399;
      font-size: 11px;
      padding: 1px 7px;
      border-radius: 999px;
      font-weight: 600;
      margin-left: 6px;
    }
    .item-desc {
      font-size: 13.5px;
      color: var(--text-sub);
      line-height: 1.55;
      white-space: pre-line;
    }

    /* Skills Pill Wrap */
    .skills-grid {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }
    .skill-pill {
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid rgba(255, 255, 255, 0.09);
      color: #E2E8F0;
      padding: 7px 14px;
      border-radius: 999px;
      font-size: 13px;
      font-weight: 500;
      transition: all 0.2s ease;
    }
    .skill-pill:hover {
      background: rgba(99, 102, 241, 0.15);
      border-color: rgba(99, 102, 241, 0.35);
      color: #EEF2FF;
    }

    /* Footer */
    .footer {
      text-align: center;
      margin-top: 16px;
      color: var(--text-muted);
      font-size: 13px;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 12px;
    }
    .footer-badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 8px 18px;
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.04);
      border: 1px solid rgba(255, 255, 255, 0.08);
      color: #94A3B8;
      text-decoration: none;
      font-size: 13px;
      font-weight: 500;
      transition: background 0.2s;
    }
    .footer-badge:hover {
      background: rgba(255, 255, 255, 0.08);
      color: #fff;
    }
  </style>
</head>
<body>
  <div class="container">
    <!-- Top Bar -->
    <header class="brand-header">
      <a href="https://joinmandala.in" class="brand-logo">
        <div class="brand-icon">M</div>
        <span>Mandala</span>
      </a>
      <a href="https://joinmandala.in" class="cta-btn">Connect on Mandala</a>
    </header>

    <!-- Profile Hero Card -->
    <div class="profile-hero">
      <div class="hero-glow"></div>
      <div class="avatar-wrapper">
        ${avatarUrl
          ? `<img src="${escapeHtml(avatarUrl)}" alt="${escapeHtml(name)}" class="avatar">`
          : `<div class="avatar-placeholder">${escapeHtml((name[0] || 'M').toUpperCase())}</div>`
        }
      </div>
      <h1 class="user-name">
        ${escapeHtml(name)}
      </h1>
      ${headline ? `<div class="headline">${escapeHtml(headline)}</div>` : ""}
      ${vibeTag ? `<div class="vibe-chip">✨ ${escapeHtml(vibeTag)}</div>` : ""}
      ${bio ? `<div class="bio">${escapeHtml(bio)}</div>` : ""}
    </div>

    <!-- Experience Section -->
    ${experience.length > 0 ? `
    <div class="section-card">
      <div class="section-title">Experience</div>
      <div class="timeline">
        ${experience.map((exp) => {
          const logo = getFaviconUrl(exp.companyUrl)
          const dateRange = [
            exp.startDate,
            exp.isCurrent ? "Present" : exp.endDate
          ].filter(Boolean).join(" – ")

          return `
          <div class="timeline-item">
            <div class="timeline-connector">
              <div class="company-logo">
                ${logo
                  ? `<img src="${escapeHtml(logo)}" alt="${escapeHtml(exp.company)}" onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';">
                     <span class="fallback-icon" style="display:none;">${escapeHtml((exp.company[0] || 'C').toUpperCase())}</span>`
                  : `<span class="fallback-icon">${escapeHtml((exp.company[0] || 'C').toUpperCase())}</span>`
                }
              </div>
              <div class="timeline-line"></div>
            </div>
            <div class="timeline-content">
              <div class="role-title">${escapeHtml(exp.role)}</div>
              <div class="company-row">
                ${exp.companyUrl
                  ? `<a href="${escapeHtml(exp.companyUrl.startsWith('http') ? exp.companyUrl : 'https://' + exp.companyUrl)}" target="_blank" rel="noopener" class="company-link">
                      ${escapeHtml(exp.company)}
                      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"></path><polyline points="15 3 21 3 21 9"></polyline><line x1="10" y1="14" x2="21" y2="3"></line></svg>
                     </a>`
                  : `<span>${escapeHtml(exp.company)}</span>`
                }
                ${exp.location ? `<span>· ${escapeHtml(exp.location)}</span>` : ""}
              </div>
              ${dateRange ? `
              <div class="date-row">
                ${escapeHtml(dateRange)}
                ${exp.isCurrent ? `<span class="current-badge">Present</span>` : ""}
              </div>` : ""}
              ${exp.description ? `<div class="item-desc">${escapeHtml(exp.description)}</div>` : ""}
            </div>
          </div>`
        }).join("")}
      </div>
    </div>` : ""}

    <!-- Education Section -->
    ${education.length > 0 ? `
    <div class="section-card">
      <div class="section-title">Education</div>
      <div class="timeline">
        ${education.map((edu) => {
          const years = [edu.startYear, edu.endYear].filter(Boolean).join(" – ")
          const degreeInfo = [edu.degree, edu.fieldOfStudy].filter(Boolean).join(" · ")
          return `
          <div class="timeline-item">
            <div class="timeline-connector">
              <div class="company-logo">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#A5B4FC" stroke-width="2"><path d="M22 10v6M2 10l10-5 10 5-10 5z"></path><path d="M6 12v5c0 2 4 3 6 3s6-1 6-3v-5"></path></svg>
              </div>
              <div class="timeline-line"></div>
            </div>
            <div class="timeline-content">
              <div class="role-title">${escapeHtml(edu.school)}</div>
              ${degreeInfo ? `<div class="company-row">${escapeHtml(degreeInfo)}</div>` : ""}
              ${years ? `<div class="date-row">${escapeHtml(years)}</div>` : ""}
              ${edu.description ? `<div class="item-desc">${escapeHtml(edu.description)}</div>` : ""}
            </div>
          </div>`
        }).join("")}
      </div>
    </div>` : ""}

    <!-- Skills Section -->
    ${skills.length > 0 ? `
    <div class="section-card">
      <div class="section-title">Skills & Superpowers</div>
      <div class="skills-grid">
        ${skills.map((s) => `<div class="skill-pill">${escapeHtml(s)}</div>`).join("")}
      </div>
    </div>` : ""}

    <!-- Footer -->
    <footer class="footer">
      <a href="https://joinmandala.in" class="footer-badge">
        <span>Connect with ${escapeHtml(name)} on Mandala</span>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
      </a>
      <p>© ${new Date().getFullYear()} Mandala · The Real World Connection Network</p>
    </footer>
  </div>
</body>
</html>`

  return new Response(html, {
    status: 200,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "public, max-age=120, s-maxage=600",
    },
  })
})
