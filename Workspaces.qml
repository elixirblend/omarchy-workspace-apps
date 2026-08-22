import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "sofos.workspaces"

  // Max app icons rendered per workspace before collapsing into "+N"
  property int maxIcons: 3
  readonly property real iconSize: Math.max(10, Math.min(14, root.barSize * 0.34))
  readonly property real tripleIconSize: Math.max(8, Math.min(10, root.barSize * 0.27))
  readonly property real singleIconSize: Math.max(15, Math.min(17, root.barSize * 0.46))

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function toplevelsOf(id) {
    var workspace = root.workspaceById(id)
    return workspace ? workspace.toplevels.values : []
  }

  function appIdOf(toplevel) {
    var wl = toplevel.wayland
    var ipc = toplevel.lastIpcObject
    if (wl && wl.appId) return String(wl.appId)
    if (ipc && (ipc.class || ipc.initialClass)) return String(ipc.class || ipc.initialClass)
    return ""
  }

  function appInfoFor(toplevel) {
    var appId = root.appIdOf(toplevel)
    var lower = appId.toLowerCase()

    // Chrome web apps expose generated Wayland app IDs rather than their
    // desktop-entry IDs. Map the installed Omarchy launchers explicitly.
    if (lower.indexOf("chrome-x.com__") === 0)
      return { "key": "x", "name": "X", "icon": "x" }
    if (lower.indexOf("chrome-discord.com__") === 0)
      return { "key": "discord", "name": "Discord", "icon": "omarchy-discord" }
    if (lower.indexOf("chrome-www.reddit.com__") === 0)
      return { "key": "reddit", "name": "Reddit", "icon": "reddit" }
    if (lower === "org.omarchy.agent")
      return { "key": "terminal", "name": "Terminal", "icon": "utilities-terminal" }

    var entry = DesktopEntries.byId(appId)
    var name = entry && entry.name ? String(entry.name) : appId
    var icon = entry && entry.icon ? String(entry.icon) : lower
    return { "key": lower, "name": name, "icon": icon }
  }

  function iconUrlFor(info) {
    var resolved = Quickshell.iconPath(info.icon, true)
    if (resolved.length > 0) return resolved
    return Quickshell.iconPath("application-x-executable", true)
  }

  function iconModelFor(id) {
    var toplevels = root.toplevelsOf(id)
    var urls = []
    var names = []
    var seen = ({})
    var appCount = 0
    for (var i = 0; i < toplevels.length; i++) {
      var info = root.appInfoFor(toplevels[i])
      if (info.key.length === 0 || seen[info.key]) continue
      seen[info.key] = true
      appCount++
      names.push(info.name)
      if (urls.length < root.maxIcons) urls.push(root.iconUrlFor(info))
    }
    return { "urls": urls, "names": names, "extra": Math.max(0, appCount - urls.length) }
  }

  function labelFor(id) {
    var names = root.iconModelFor(id).names
    return names.length > 0 ? "Workspace " + id + ": " + names.join(", ") : ("Workspace " + id + ": empty")
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
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

        bar: root.bar
        text: modelData === 10 ? "0" : String(modelData)
        labelVisible: !occupied
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.barSize
        fixedHeight: root.barSize
        tooltipText: root.labelFor(modelData)
        onPressed: function() { root.focusWorkspace(modelData) }

        Rectangle {
          visible: button.occupied
          anchors.fill: parent
          anchors.margins: 2
          radius: 6
          color: button.focused ? Color.accent : (button.bar ? button.bar.barForeground : Color.foreground)
          opacity: button.focused ? 0.10 : 0.035
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
                if (count >= 3 && index === 2) return parent.height - height - 3
                return 4
              }
              fillMode: Image.PreserveAspectFit
              smooth: true
            }
          }

          Text {
            visible: button.icons.extra > 0
            anchors.right: parent.right
            anchors.rightMargin: 3
            anchors.top: parent.top
            anchors.topMargin: 2
            text: "+" + button.icons.extra
            color: button.bar ? button.bar.barForeground : Color.foreground
            font.family: button.fontFamily
            font.pixelSize: Math.max(7, button.fontSize * 0.54)
            font.weight: Font.DemiBold
            style: Text.Outline
            styleColor: Color.background
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
        }

        Rectangle {
          visible: button.focused
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 1
          anchors.horizontalCenter: parent.horizontalCenter
          width: parent.width * 0.38
          height: 2
          radius: 1
          color: Color.accent
        }
      }
    }
  }
}
