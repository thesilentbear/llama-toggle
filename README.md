# llama-toggle

A one-button Omarchy widget for your llama.cpp server.

Your inference server chugs along in the background — great until you sit down
to a game and it fights for the CPU/GPU. `llama-toggle` puts a single button
in your bar: click to pause the server, click again to resume, no terminal
needed.

It controls the server through **systemd user units**, so it never touches the
llama process directly — crashes and restarts are picked up automatically.

## Requirements

- A systemd **user** unit for your llama.cpp server. By default the widget
  controls `llama-35b.service`; point it at your unit with:

  ```bash
  omarchy bar set dev.thesilentbear.llama-toggle unit llama-35b.service
  ```

## Installation

```bash
omarchy plugin add https://github.com/thesilentbear/llama-toggle.git --yes
omarchy bar move dev.thesilentbear.llama-toggle --section right
```

A small pill in the bar spells the state out: a power glyph plus `ON`/`OFF`,
all colored from the installed theme (the `OFF` pill uses the theme's
active/danger token, so it turns red when a red-having theme is active).
Left-click toggles it; hovering shows the unit name and current state.

## How it works

- Every 2s the widget runs `systemctl --user is-active <unit>` to learn the
  server's state (loading counts as running).
- Clicking runs `systemctl --user start` or `stop` detached, and flips the
  state optimistically so the response feels instant.

## Control from the terminal

Each widget instance also exposes a small IPC API:

```bash
omarchy-shell dev.thesilentbear.llama-toggle status   # running | stopped
omarchy-shell dev.thesilentbear.llama-toggle toggle   # flip it
```

## Repository layout

```
manifest.json        plugin manifest (schemaVersion 1, bar-widget kind)
BarWidget.qml        the widget — state pill (icon + ON/OFF), probe, toggle
```

MIT — see [LICENSE](LICENSE). No affiliation with llama.cpp or its authors.