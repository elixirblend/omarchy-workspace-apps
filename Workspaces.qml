import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "sofos.workspaces"

  readonly property int maxIcons: Math.max(1, Math.min(3, Number(setting("maxIcons", 3))))
  readonly property int minimumWorkspaces: Math.max(1, Math.min(10, Number(setting("minimumWorkspaces", 5))))
  readonly property bool scrollToSwitch: setting("scrollToSwitch", true) === true
  readonly property bool showUrgent: setting("showUrgent", true) === true
  readonly property bool animateChanges: setting("animateChanges", true) === true
  readonly property bool showAudio: setting("showAudio", true) === true
  readonly property bool showArrivalFlash: setting("showArrivalFlash", true) === true
  readonly property bool showCompletionFlash: setting("showCompletionFlash", true) === true
  readonly property var mediaPlayers: Mpris.players ? Mpris.players.values : []
  readonly property var mediaService: bar && bar.shell ? bar.shell.firstPartyServiceFor("omarchy.media") : null
  readonly property var playbackStreams: mediaService ? mediaService.playbackStreams : []
  readonly property var notificationService: bar && bar.shell ? bar.shell.firstPartyServiceFor("omarchy.notifications") : null
  readonly property var notificationModel: notificationService ? notificationService.popupModel : null
  property string lastCompletionNotification: ""
  property var completionSerials: ({})
  readonly property int maxToplevels: 64
  readonly property int maxTooltipNames: 12
  readonly property int maxTooltipNameLength: 80
  readonly property int maxAppIdLength: 256
  readonly property real iconSize: Math.max(10, Math.min(14, root.barSize * 0.34))
  readonly property real tripleIconSize: Math.max(9, Math.min(11, (root.barSize - 3) / 2))
  readonly property real singleIconSize: Math.max(15, Math.min(17, root.barSize * 0.46))

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    return Model.workspaceIds(Hyprland.workspaces.values, root.minimumWorkspaces, 10)
  }

  function toplevelsOf(id) {
    var workspace = root.workspaceById(id)
    return workspace ? workspace.toplevels.values : []
  }

  function appIdOf(toplevel) {
    var wl = toplevel.wayland
    var ipc = toplevel.lastIpcObject
    if (wl && wl.appId) return String(wl.appId).slice(0, root.maxAppIdLength)
    if (ipc && (ipc.class || ipc.initialClass)) return String(ipc.class || ipc.initialClass).slice(0, root.maxAppIdLength)
    return ""
  }

  function appInfoFor(toplevel) {
    var appId = root.appIdOf(toplevel)
    var entry = DesktopEntries.byId(appId)
    return Model.appDescriptor(appId,
      entry && entry.name ? String(entry.name) : "",
      entry && entry.icon ? String(entry.icon) : "")
  }

  function iconUrlFor(info) {
    for (var i = 0; i < info.icons.length; i++) {
      if (!info.icons[i]) continue
      var resolved = Quickshell.iconPath(info.icons[i], true)
      if (resolved.length > 0) return resolved
    }
    return Quickshell.iconPath("application-x-executable", true)
  }

  // WidgetButton tooltips use rich text, so desktop-entry names must be
  // bounded and escaped before they reach tooltipText.
  function safeTooltipText(value) {
    return Model.safeTooltipText(value, root.maxTooltipNameLength)
  }

  function iconModelFor(id) {
    var toplevels = root.toplevelsOf(id)
    var urls = []
    var names = []
    var seen = ({})
    var appCount = 0
    var limit = Math.min(toplevels.length, root.maxToplevels)
    for (var i = 0; i < limit; i++) {
      var info = root.appInfoFor(toplevels[i])
      if (info.key.length === 0 || seen[info.key]) continue
      seen[info.key] = true
      appCount++
      if (names.length < root.maxTooltipNames) names.push(root.safeTooltipText(info.name))
      if (urls.length < root.maxIcons) urls.push(root.iconUrlFor(info))
    }
    return { "urls": urls, "names": names, "extra": Math.max(0, appCount - urls.length) }
  }

  function labelFor(id) {
    var names = root.iconModelFor(id).names
    var label = names.length > 0 ? "Workspace " + id + ": " + names.join(", ") : ("Workspace " + id + ": empty")
    return root.workspaceHasAudio(id) ? label + " • audio playing" : label
  }

  function playerInfo(player) {
    var metadata = player && player.metadata ? player.metadata : ({})
    return {
      desktopEntry: player ? player.desktopEntry : "",
      identity: player ? player.identity : "",
      dbusName: player ? player.dbusName : "",
      url: metadata["xesam:url"] || metadata["url"] || ""
    }
  }

  function workspaceHasAudio(id) {
    if (!root.showAudio) return false
    var toplevels = root.toplevelsOf(id)
    var activeStreamPids = []

    // PipeWire is authoritative for actual audio streams. Mapping by PID also
    // identifies the correct browser workspace when MPRIS says Paused/Stopped.
    for (var streamIndex = 0; streamIndex < root.playbackStreams.length; streamIndex++) {
      var stream = root.playbackStreams[streamIndex]
      var properties = stream && stream.properties ? stream.properties : ({})
      if (String(properties["pulse.corked"] || "false") === "true") continue
      var streamPid = Number(properties["application.process.id"] || 0)
      if (streamPid <= 0) continue
      if (activeStreamPids.indexOf(streamPid) === -1) activeStreamPids.push(streamPid)
      for (var streamTopIndex = 0; streamTopIndex < toplevels.length; streamTopIndex++) {
        var ipc = toplevels[streamTopIndex].lastIpcObject
        if (ipc && Number(ipc.pid || 0) === streamPid) return true
      }
    }

    // If PipeWire supplied concrete process IDs, do not let fuzzy MPRIS URL
    // matching mark another browser or PWA workspace for the same playback.
    if (activeStreamPids.length > 0) return false

    for (var playerIndex = 0; playerIndex < root.mediaPlayers.length; playerIndex++) {
      var player = root.mediaPlayers[playerIndex]
      if (!player || !player.isPlaying) continue
      var info = root.playerInfo(player)
      for (var topIndex = 0; topIndex < toplevels.length; topIndex++) {
        if (Model.playerMatchesApp(info, root.appIdOf(toplevels[topIndex]))) return true
      }
    }
    return false
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  function switchWorkspace(delta) {
    var step = Model.wheelStep(delta)
    if (!root.scrollToSwitch || step === 0 || !root.bar) return
    root.bar.run("hyprctl dispatch workspace " + (step > 0 ? "e+1" : "e-1"))
  }

  function workspaceForNotification(appName, appIcon) {
    var ids = root.workspaceIds()
    for (var idIndex = 0; idIndex < ids.length; idIndex++) {
      var toplevels = root.toplevelsOf(ids[idIndex])
      for (var topIndex = 0; topIndex < toplevels.length; topIndex++) {
        if (Model.notificationMatchesApp(appName, appIcon, root.appIdOf(toplevels[topIndex]))) return ids[idIndex]
      }
    }
    return 0
  }

  function handleNotificationChange() {
    if (!root.showCompletionFlash || !root.notificationModel || root.notificationModel.count < 1) return
    var row = root.notificationModel.get(0)
    if (!row || !Model.isCompletionNotification(row.summary, row.body)) return
    var key = String(row.originalId) + ":" + String(row.timestamp)
    if (key === root.lastCompletionNotification) return
    root.lastCompletionNotification = key
    var workspaceId = root.workspaceForNotification(row.appName, row.appIcon)
    if (workspaceId <= 0) return
    var next = ({})
    for (var existing in root.completionSerials) next[existing] = root.completionSerials[existing]
    next[String(workspaceId)] = Number(next[String(workspaceId)] || 0) + 1
    root.completionSerials = next
  }

  Connections {
    target: root.notificationModel
    ignoreUnknownSignals: true
    function onCountChanged() { Qt.callLater(root.handleNotificationChange) }
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        id: button

        required property int modelData

        readonly property var icons: occupied || focused ? root.iconModelFor(modelData) : { "urls": [], "names": [], "extra": 0 }
        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
        readonly property bool urgent: root.showUrgent && workspace !== null && workspace.urgent
        readonly property bool playingAudio: root.workspaceHasAudio(modelData)
        readonly property int toplevelCount: workspace !== null ? workspace.toplevels.values.length : 0
        readonly property int completionSerial: Number(root.completionSerials[String(modelData)] || 0)
        property int previousToplevelCount: 0
        property bool countInitialized: false

        onToplevelCountChanged: {
          if (countInitialized && root.showArrivalFlash && toplevelCount > previousToplevelCount)
            arrivalAnimation.restart()
          previousToplevelCount = toplevelCount
        }
        onCompletionSerialChanged: if (countInitialized && completionSerial > 0) completionAnimation.restart()
        Component.onCompleted: {
          previousToplevelCount = toplevelCount
          countInitialized = true
        }

        bar: root.bar
        text: modelData === 10 ? "0" : String(modelData)
        labelVisible: !occupied
        opacity: occupied || focused || urgent ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.barSize
        fixedHeight: root.barSize
        tooltipText: root.labelFor(modelData)
        onPressed: function() { root.focusWorkspace(modelData) }
        onWheelMoved: function(delta) { root.switchWorkspace(delta) }

        Behavior on opacity {
          enabled: root.animateChanges
          NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        Rectangle {
          visible: button.occupied
          anchors.fill: parent
          anchors.margins: 2
          radius: 6
          color: button.urgent ? (button.bar ? button.bar.urgent : Color.urgent)
            : (button.focused ? Color.accent : (button.bar ? button.bar.barForeground : Color.foreground))
          opacity: button.urgent ? 0.18 : (button.focused ? 0.10 : 0.035)

          Behavior on color {
            enabled: root.animateChanges
            ColorAnimation { duration: 180 }
          }
          Behavior on opacity {
            enabled: root.animateChanges
            NumberAnimation { duration: 180 }
          }
        }

        Item {
          visible: button.occupied
          anchors.centerIn: parent
          width: root.barSize
          height: root.barSize

          Repeater {
            model: button.icons.urls

            Image {
              required property int index
              required property string modelData
              readonly property real renderedSize: button.icons.urls.length === 1
                ? root.singleIconSize
                : (button.icons.urls.length >= 3 ? root.tripleIconSize : root.iconSize)
              source: modelData
              sourceSize.width: renderedSize
              sourceSize.height: renderedSize
              width: renderedSize
              height: renderedSize
              x: {
                var count = button.icons.urls.length
                if (count === 1) return (parent.width - width) / 2
                if (count === 2) return parent.width / 2 - width + index * width
                // Three icons use a compact 2-over-1 layout. Keeping the
                // third icon on the lower-left leaves the workspace number
                // readable in the lower-right corner.
                if (index < 2) return parent.width / 2 - width + index * width
                return 3
              }
              y: {
                var count = button.icons.urls.length
                if (count === 1) return (parent.height - height) / 2 - 1
                if (count >= 3 && index === 2) return parent.height - height - 2
                return count >= 3 ? 2 : 4
              }
              fillMode: Image.PreserveAspectFit
              smooth: true

              Behavior on opacity {
                enabled: root.animateChanges
                NumberAnimation { duration: 140 }
              }
            }
          }

          Text {
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            text: button.modelData === 10 ? "0" : String(button.modelData)
            color: button.bar ? button.bar.barForeground : Color.foreground
            font.family: button.fontFamily
            font.pixelSize: Math.max(7, button.fontSize * 0.58)
            font.weight: Font.DemiBold
            style: Text.Outline
            styleColor: Color.background
          }

          Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 1
            anchors.top: parent.top
            anchors.topMargin: 1
            visible: button.playingAudio
            width: 10
            height: 10
            radius: width / 2
            color: Color.accent
            z: 3

            Text {
              anchors.centerIn: parent
              text: "󰕾"
              color: Color.background
              font.family: button.fontFamily
              font.pixelSize: 7
            }

          }
        }

        Rectangle {
          visible: button.focused || button.urgent
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 1
          anchors.horizontalCenter: parent.horizontalCenter
          width: parent.width * 0.38
          height: 2
          radius: 1
          color: button.urgent ? (button.bar ? button.bar.urgent : Color.urgent) : Color.accent

          Behavior on width {
            enabled: root.animateChanges
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
          }
          Behavior on color {
            enabled: root.animateChanges
            ColorAnimation { duration: 180 }
          }
        }

        Rectangle {
          anchors.fill: parent
          anchors.margins: 1
          radius: 7
          color: Color.accent
          opacity: 0
          z: 4

          SequentialAnimation on opacity {
            id: arrivalAnimation
            running: false
            NumberAnimation { to: 0.28; duration: 90; easing.type: Easing.OutCubic }
            NumberAnimation { to: 0; duration: 520; easing.type: Easing.OutCubic }
          }
        }

        Rectangle {
          anchors.fill: parent
          anchors.margins: 1
          radius: 7
          color: "#55c878"
          opacity: 0
          z: 5

          Text {
            anchors.centerIn: parent
            text: "✓"
            color: Color.background
            font.family: button.fontFamily
            font.pixelSize: Math.max(10, button.fontSize * 0.85)
            font.bold: true
          }

          SequentialAnimation on opacity {
            id: completionAnimation
            running: false
            NumberAnimation { to: 0.72; duration: 110; easing.type: Easing.OutCubic }
            PauseAnimation { duration: 180 }
            NumberAnimation { to: 0; duration: 650; easing.type: Easing.OutCubic }
          }
        }
      }
    }
  }
}
