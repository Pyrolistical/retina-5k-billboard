# client

- runs on your machine, mirrors a tmux window to the billboard
- systemd user unit `billboard-mirror` running `client/mirror`
- settings: see [Settings](../README.md#settings)

## Install

- `client/install.sh`
  - `SESSION` unset: uses your only tmux session and saves it to the root `.env`, fails when there are none or several
  - writes `~/.config/systemd/user/billboard-mirror.service`, enables and starts it
  - `loginctl enable-linger`, so it starts at boot without a login

## Start / stop

- start: `systemctl --user start billboard-mirror`
- stop: `systemctl --user stop billboard-mirror`
  - the billboard shows `no billboard-mirror service connected to <billboard IP>`
- restart, after changing `.env` or `client/mirror`: `systemctl --user restart billboard-mirror`
- status: `systemctl --user status billboard-mirror`
- logs: `journalctl --user -u billboard-mirror -f`
- off at boot: `systemctl --user disable --now billboard-mirror`, back on: `systemctl --user enable --now billboard-mirror`

## How it works

- one ssh connection running `cat > /run/billboard-terminal`, a frame every `FRAME_SECONDS`
- the billboard's `billboard-terminal` service shows that fifo in foot, fullscreen in cage
- never starts the tmux server; until session `SESSION` exists the billboard shows `start tmux session SESSION to begin mirroring window WINDOW`
- links the window back into `SESSION` whenever it is missing, e.g. after `SESSION` is recreated
- connection
  - keepalives every 10 s, either end drops a dead connection after 30 s
  - when the connection ends, the billboard shows `no billboard-mirror service connected to <billboard IP>`
  - after a drop, reconnects only while a tmux client shows the window, retrying every 2 s
- helper tmux sessions
  - `billboard` holds the window
  - `billboard-render` runs an `ignore-size` client of `billboard`, its pane is captured each frame
