# Workspace Apps for Omarchy

> See what is happening across your desktop without leaving the bar.

Workspace Apps turns Omarchy's workspace switcher into a compact live overview. Each tile combines the workspace number, application icons, urgency, audio activity, and lightweight event feedback while staying faithful to Omarchy's visual language.

![Workspace Apps showing grouped application icons and workspace numbers](assets/workspace-apps.png)

## Why Workspace Apps?

The stock workspace widget tells you *where* you are. Workspace Apps also tells you *what is there*.

- Up to three application icons in each compact tile
- Clear active-workspace underline and subtle occupied states
- Click to focus and scroll to move between workspaces
- Urgent-window highlighting using the active Omarchy theme
- Static speaker badge for active PipeWire audio
- Short arrival flash when a new window opens
- Green completion flash when an app reports a finished task
- Clean, bounded tooltips with application names
- Horizontal and vertical bar support
- Native settings in Omarchy's bar configuration

## Smart application detection

Workspace Apps resolves normal desktop entries, Omarchy terminals, and Chrome PWAs. It includes mappings for popular apps such as ChatGPT, Discord, Gmail, Google Calendar, Reddit, WhatsApp, X, and YouTube, while deriving sensible names and icon candidates for unknown web apps.

Duplicate applications are grouped so the widget remains useful even when a workspace gets busy. All external names are bounded and escaped before appearing in rich-text tooltips.

## Install

```bash
omarchy plugin add https://github.com/elixirblend/omarchy-workspace-apps --enable
omarchy plugin enable sofos.workspaces --section left
```

The plugin reloads automatically after installation. If an updated widget does not appear immediately, restart the shell once:

```bash
omarchy restart shell
```

## Configure

Select **Workspace Apps** in Omarchy's bar settings, or configure the widget directly in `~/.config/omarchy/shell.json`:

```json
{
  "id": "sofos.workspaces",
  "minimumWorkspaces": 5,
  "maxIcons": 3,
  "scrollToSwitch": true,
  "showUrgent": true,
  "showAudio": true,
  "showArrivalFlash": true,
  "showCompletionFlash": true,
  "animateChanges": true
}
```

| Option | Default | Description |
| --- | ---: | --- |
| `minimumWorkspaces` | `5` | Always show at least this many workspaces, from 1 to 10. |
| `maxIcons` | `3` | Show between one and three unique application icons per tile. |
| `scrollToSwitch` | `true` | Switch to the previous or next occupied workspace by scrolling. |
| `showUrgent` | `true` | Highlight workspaces containing windows that request attention. |
| `showAudio` | `true` | Show a speaker badge on the workspace producing audio. |
| `showArrivalFlash` | `true` | Briefly flash a tile when a new window appears. |
| `showCompletionFlash` | `true` | Flash green when a matching app sends a completion notification. |
| `animateChanges` | `true` | Animate focus, occupancy, and urgency transitions. |

You can also change individual options from the terminal:

```bash
omarchy bar set sofos.workspaces maxIcons 2
omarchy bar set sofos.workspaces showArrivalFlash false
```

## Completion notifications

The completion effect responds to notifications whose title includes a completion term such as `finished`, `completed`, `passed`, `built`, or `ready`. The notification sender must match an application currently visible on a workspace.

You can test it with Firefox open:

```bash
notify-send -a Firefox "Build finished" "All tasks passed"
```

## Development

Clone or edit the plugin under `~/.config/omarchy/plugins/sofos.workspaces`, then run:

```bash
node tests/model-test.js
omarchy plugin validate .
omarchy restart shell
```

The model tests cover workspace filtering, PWA identification, icon metadata, tooltip safety, media matching, notification matching, and completion detection.

## Troubleshooting

If the bar reports a plugin reload but still shows an older version, use `omarchy restart shell`. Omarchy may retain an existing QML widget instance during a hot reload.

Audio detection uses active, non-corked PipeWire playback streams and maps their process IDs to Hyprland windows. This prevents a Firefox stream from incorrectly marking a similarly named Chrome PWA on another workspace.

## Remove

```bash
omarchy plugin remove sofos.workspaces
```

## License

[MIT](LICENSE) © Elixir Blend
