const assert = require("node:assert/strict")
const Model = require("../Model.js")

assert.deepEqual(Model.workspaceIds([{ id: 7 }, { id: -99 }, { id: 2 }], 5, 10), [1, 2, 3, 4, 5, 7])
assert.deepEqual(Model.workspaceIds([{ id: 11 }], 3, 10), [1, 2, 3])
assert.equal(Model.pwaHost("chrome-mail.google.com__-Default"), "mail.google.com")
assert.equal(Model.pwaHost("firefox"), "")

assert.deepEqual(Model.appDescriptor("chrome-chatgpt.com__-Default", "", ""), {
  key: "chatgpt",
  name: "ChatGPT",
  icons: ["chatgpt", "openai"]
})
assert.deepEqual(Model.appDescriptor("chrome-example.test__-Default", "", ""), {
  key: "example.test",
  name: "Example",
  icons: ["example", "example.test", "web-browser"]
})
assert.deepEqual(Model.appDescriptor("org.example.App", "Example App", "example-icon"), {
  key: "org.example.app",
  name: "Example App",
  icons: ["example-icon", "org.example.app", "application-x-executable"]
})

assert.equal(Model.safeTooltipText("A < B & C", 80), "A &lt; B &amp; C")
assert.equal(Model.safeTooltipText("123456", 4), "1234")
assert.equal(Model.wheelStep(120), -1)
assert.equal(Model.wheelStep(-120), 1)
assert.equal(Model.wheelStep(0), 0)
assert.equal(Model.playerMatchesApp({ desktopEntry: "spotify", identity: "Spotify", url: "" }, "spotify"), true)
assert.equal(Model.playerMatchesApp({ desktopEntry: "spotify", identity: "Spotify", url: "" }, "com.spotify.Client"), true)
assert.equal(Model.playerMatchesApp({ desktopEntry: "org.mozilla.firefox", identity: "Firefox", url: "" }, "firefox"), true)
assert.equal(Model.playerMatchesApp({ desktopEntry: "google-chrome", identity: "Chrome", url: "https://www.youtube.com/watch?v=1" }, "chrome-www.youtube.com__-Default"), true)
assert.equal(Model.playerMatchesApp({ desktopEntry: "google-chrome", identity: "Chrome", url: "https://music.example.com" }, "chrome-www.youtube.com__-Default"), false)
assert.equal(Model.playerMatchesApp({ desktopEntry: "spotify", identity: "Spotify", url: "" }, "kitty"), false)
assert.equal(Model.notificationMatchesApp("Firefox", "firefox", "firefox"), true)
assert.equal(Model.notificationMatchesApp("Spotify", "spotify", "com.spotify.Client"), true)
assert.equal(Model.notificationMatchesApp("Discord", "discord", "firefox"), false)
assert.equal(Model.isCompletionNotification("Build finished", "All targets passed"), true)
assert.equal(Model.isCompletionNotification("New message", "Ready for lunch?"), false)
assert.equal(Model.isCompletionNotification("New message", "Hello there"), false)

console.log("workspace model tests passed")
