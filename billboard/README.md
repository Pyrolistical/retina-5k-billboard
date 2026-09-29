# billboard

- runs on your machine, shows images and videos fullscreen on the billboard
- usage and keys: see [Image & video support](../README.md#image--video-support)
- settings: see [Settings](../README.md#settings)

## Install

- from the repo root: `ln -s "$PWD/billboard/billboard" ~/.local/bin/billboard`

## Behaviour

- stops at the first and last file, no wrap
- videos loop, images stay until you move on
- terminal status line: `2/5 0001-clip.mp4  vol 60  > 0:01.12 [###---------------------------] 0:10.00  frame 29/250`
  - `vol` only when the file has audio, `muted` when muted
  - scrubber only for videos, `||` when paused
- `fd -0 yada | xargs -0 billboard` works too, plain `xargs` splits names on spaces
- a new `billboard` replaces the one showing
- volume is the iMac's hardware mixer, kept across runs and reboots

## Files

- uploads
  - to `/tmp/billboard-<pid>/` on the billboard, as `<index>-<name>`, deleted when `billboard` exits
  - the first file before showing, the rest in the background in order
  - written to `.part` then renamed, a partial file is never shown
  - a file not uploaded yet shows its name and upload percentage, then switches to the file when it arrives
- paths under `SHARES` are not uploaded, the billboard opens the same path on its own mount

## How it works

- `show` on the billboard runs mpv fullscreen in cage, over the mirrored terminal, installed by `install/install.sh`
- the ssh calls of a run share one connection, kept open 60 s so the next run starts faster (`ControlMaster`, `~/.ssh/cm-*`)
