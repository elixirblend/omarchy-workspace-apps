function boundedString(value, maxLength) {
  return String(value || "").slice(0, maxLength)
}

function workspaceIds(workspaces, minimumCount, maximumId) {
  var ids = []
  var minimum = Math.max(1, Math.min(maximumId, Number(minimumCount) || 5))
  for (var id = 1; id <= minimum; id++) ids.push(id)

  for (var i = 0; i < workspaces.length; i++) {
    var workspaceId = Number(workspaces[i].id)
    if (workspaceId > 0 && workspaceId <= maximumId && ids.indexOf(workspaceId) === -1)
      ids.push(workspaceId)
  }

  return ids.sort(function(left, right) { return left - right })
}

function pwaHost(appId) {
  var match = String(appId || "").toLowerCase().match(/^chrome-(.+?)__(?:-|$)/)
  return match ? match[1] : ""
}

function titleCaseHost(host) {
  var label = host.replace(/^www\./, "").split(".")[0].replace(/[-_]+/g, " ")
  return label.replace(/\b\w/g, function(character) { return character.toUpperCase() })
}

function appDescriptor(appId, desktopName, desktopIcon) {
  var raw = String(appId || "")
  var lower = raw.toLowerCase()
  var known = {
    "chrome-x.com__": ["x", "X", ["x"]],
    "chrome-discord.com__": ["discord", "Discord", ["omarchy-discord", "discord"]],
    "chrome-www.reddit.com__": ["reddit", "Reddit", ["reddit"]],
    "chrome-chatgpt.com__": ["chatgpt", "ChatGPT", ["chatgpt", "openai"]],
    "chrome-mail.google.com__": ["gmail", "Gmail", ["gmail", "mail-google"]],
    "chrome-calendar.google.com__": ["google-calendar", "Google Calendar", ["google-calendar"]],
    "chrome-www.youtube.com__": ["youtube", "YouTube", ["youtube"]],
    "chrome-web.whatsapp.com__": ["whatsapp", "WhatsApp", ["whatsapp"]]
  }

  for (var prefix in known) {
    if (lower.indexOf(prefix) === 0)
      return { key: known[prefix][0], name: known[prefix][1], icons: known[prefix][2] }
  }

  if (lower === "org.omarchy.agent")
    return { key: "terminal", name: "Terminal", icons: ["utilities-terminal", "terminal"] }

  var host = pwaHost(lower)
  if (host) {
    var slug = host.replace(/^www\./, "").replace(/\.[^.]+$/, "").replace(/[^a-z0-9]+/g, "-")
    return { key: host, name: titleCaseHost(host), icons: [slug, host, "web-browser"] }
  }

  return {
    key: lower,
    name: desktopName || raw,
    icons: [desktopIcon || "", lower, "application-x-executable"]
  }
}

function safeTooltipText(value, maxLength) {
  return boundedString(value, maxLength)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\"/g, "&quot;")
    .replace(/'/g, "&#39;")
}

function wheelStep(delta) {
  if (delta > 0) return -1
  if (delta < 0) return 1
  return 0
}

function normalizedAppToken(value) {
  return String(value || "").toLowerCase()
    .replace(/\.desktop$/, "")
    .replace(/^org\./, "")
    .replace(/[^a-z0-9]+/g, "")
}

function playerMatchesApp(player, appId) {
  var app = String(appId || "").toLowerCase()
  if (!app) return false

  var host = pwaHost(app)
  var mediaUrl = String(player.url || "").toLowerCase()
  if (host) return mediaUrl.indexOf(host.replace(/^www\./, "")) !== -1

  var appToken = normalizedAppToken(app)
  var appSegments = app.replace(/\.desktop$/, "").split(/[^a-z0-9]+/).filter(Boolean)
  var candidates = [player.desktopEntry, player.identity, player.dbusName]
  for (var i = 0; i < candidates.length; i++) {
    var candidate = normalizedAppToken(candidates[i])
    if (candidate.length < 3) continue
    if (candidate === appToken || appToken.endsWith(candidate) || candidate.endsWith(appToken)) return true
    if (appSegments.indexOf(candidate) !== -1) return true
  }

  return false
}

function notificationMatchesApp(appName, appIcon, appId) {
  var app = String(appId || "").toLowerCase()
  var appToken = normalizedAppToken(app)
  var appSegments = app.replace(/\.desktop$/, "").split(/[^a-z0-9]+/).filter(Boolean)
  var candidates = [appName, appIcon]
  for (var i = 0; i < candidates.length; i++) {
    var candidate = normalizedAppToken(candidates[i])
    if (candidate.length < 3) continue
    if (candidate === appToken || appToken.endsWith(candidate) || candidate.endsWith(appToken)) return true
    if (appSegments.indexOf(candidate) !== -1) return true
  }
  return false
}

function isCompletionNotification(summary, body) {
  var title = String(summary || "").toLowerCase()
  return /\b(done|complete|completed|finished|success|succeeded|ready|passed|built|downloaded|exported|rendered)\b/.test(title)
}

var api = {
  workspaceIds: workspaceIds,
  pwaHost: pwaHost,
  appDescriptor: appDescriptor,
  safeTooltipText: safeTooltipText,
  wheelStep: wheelStep,
  normalizedAppToken: normalizedAppToken,
  playerMatchesApp: playerMatchesApp,
  notificationMatchesApp: notificationMatchesApp,
  isCompletionNotification: isCompletionNotification
}

if (typeof module !== "undefined") module.exports = api
