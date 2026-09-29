# retina-5k-billboard

Turn a late 2014 iMac Retina 5K into a dumb 5K billboard.

## Setup

- Assumes local computer is Arch Linux
- see [install/INSTALL.md](install/INSTALL.md)

## Features

### One mirrored tmux window

- a tmux window on the 5K screen
- programs run on your machine, the billboard only gets frames

**How to use**

1. switch to window `billboard` in your tmux session
2. run anything

<details>
<summary>Details</summary>

- window `WINDOW` linked into tmux session `SESSION`, shows in its status bar, splits included
- size
  - while a tmux client shows it: that client's size, drawn top-left, the rest filled with `·`
  - otherwise: the whole screen, `COLS`x`ROWS` (320x90)
- close it and a fresh one comes back
- foot on the billboard: true color, no cursor
- start / stop and how it works: [client/README.md](client/README.md)

</details>

### Image & video support

- files fullscreen, one at a time, like `less`, controlled from your terminal
- files are uploaded on the fly, or read from shares the billboard mounts itself

**How to use**

1. `billboard a.png b.mp4`, or one path per line: `fd -e png | billboard`
2. `space` / `n` next, `p` previous
3. `up` / `down` volume ±5, `m` mute
4. videos: `k` pause/play, `left` / `right` seek 2 s, `,` / `.` one frame back/forward
5. `q` back to the tmux window

- details: [billboard/README.md](billboard/README.md)

### Always on

- the screen never blanks
- optional daily power off and wake up

**How to use**

1. before install, add `OFF_UTC=07:00` and `ON_UTC=17:00` to the root `.env`

<details>
<summary>Details</summary>

- `display-off.timer` runs `rtcwake -m off` at `OFF_UTC` with the RTC alarm at the next `ON_UTC`
- the mirror reconnects after the billboard boots

</details>

## Settings

- `.env` files, the root `.env` holds your machine specific values

<details>
<summary>Details</summary>

- `billboard/.env`, `client/.env` and `install/.env`, loaded by `env.sh`
- a blank key falls back to the root `.env` (gitignored)
- scripts fail when a key they require is blank in both
- root `.env`: `IP`, `ROOT_PASSWORD`, `SESSION` (set by `client/install.sh` when you have one tmux session), optional `SHARES` (space separated paths)
- `client/.env`: `WINDOW` name, `COLS` / `ROWS` size in cells, `FRAME_SECONDS` capture interval
- `install/.env`: Arch ISO, hostname, timezone, `DISK`, optional `OFF_UTC` / `ON_UTC`, Apple `diags.efi` URL and sha256
- all three: `SSH_KEY_NAME`, log in with `ssh -i ~/.ssh/id_billboard root@$IP`

</details>
