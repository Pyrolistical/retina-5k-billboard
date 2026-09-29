# Install

End point: a dumb 5K billboard. The iMac boots to a blank 5120x2880 screen with no login, reachable over ssh by key from the control machine, showing what it pushes: terminal frames in foot and `show` for fullscreen images and videos. It has no access to the control machine. The screen never blanks.

## Steps

Needs: an iMac15,1, a USB stick, wired ethernet, an Arch Linux control machine with tmux. The install erases the iMac's disk.

1. Clone the repo on the control machine, run the remaining steps from its root:

   ```sh
   git clone https://github.com/Pyrolistical/retina-5k-billboard.git
   cd retina-5k-billboard
   ```

2. Reserve a DHCP address for the iMac's ethernet
3. Create `.env` in the repo root:

   ```sh
   IP=192.168.1.50
   ROOT_PASSWORD=change-me
   SHARES=
   ```

   - optional daily power schedule: add `OFF_UTC=07:00` and `ON_UTC=17:00`
   - check `DISK` in `install/.env`
4. Write the USB stick: `install/usb.sh /dev/sdX`, type `ERASE` to confirm
5. Plug the USB into the iMac, hold Option at power on, pick EFI Boot
6. Once the live system answers ssh, run `install/deploy.sh`, type `ERASE` to confirm
7. Once the iMac reboots into the billboard, remove the USB stick
8. Start the terminal mirror: `client/install.sh`
9. Put `billboard` on your path: `ln -s "$PWD/billboard/billboard" ~/.local/bin/billboard`
10. Optional, for `SHARES`: mount the same shares on the billboard at the same paths

## What the scripts do

- `usb.sh`
  - creates the control key `~/.ssh/id_billboard` unless it exists
  - runs `disk-report`: refuses a non-USB disk, shows model, serial, capacity, partitions, file systems and free space
  - erases nothing unless you type `ERASE`
  - downloads the ISO + `.sig`, verifies with `gpgv` against `/usr/share/pacman/keyrings/archlinux.gpg`
  - writes the ISO, appends a 64M FAT `CIDATA` partition
  - cloud-init `user-data` authorizes the control key for root on the live system
- `deploy.sh`
  - runs `disk-report` on the live system: refuses a removable or USB `DISK` (default `/dev/sda`), shows model, serial, capacity, partitions, file systems and free space
  - erases nothing unless you type `ERASE`
  - tars `env.sh`, root `.env`, `install/{.env,install.sh,show}` and `~/.ssh/id_billboard.pub` into `/root` on the live system over one ssh connection
  - runs `install/install.sh` as a systemd unit, follows `/root/install.log`, reboots on success
- `install.sh`
  - fails unless `IP` and `ROOT_PASSWORD` are set, and `OFF_UTC` / `ON_UTC` are both set or both blank
  - GPT: 1G ESP on `/boot`, ext4 root
  - pacstrap, networkd DHCP, sshd root login by control key only, no passwords, drops silent clients after 30 s, `getty@tty1` disabled, `billboard-terminal.service`, `show`, `ttf-dejavu`
  - `display-off.timer` at `OFF_UTC`, only when set: `rtcwake -m off` with the alarm at the next `ON_UTC`
  - UKI + Apple `diags.efi` 5K chain, systemd-boot 4K fallback, EFI boot entries
  - does not mount `SHARES`
- `client/install.sh`
  - `SESSION` unset: uses your only tmux session and saves it to the root `.env`, fails when there are none or several
  - writes `~/.config/systemd/user/billboard-mirror.service`, enables and starts it
  - `loginctl enable-linger`, so it starts at boot without a login
  - start / stop: see [client/README.md](../client/README.md)

## Debugging

- recovery: hold Option at power on, pick EFI Boot, systemd-boot starts Linux in 4K with amdgpu, entries in `/boot/loader/entries/`
- 5K check: `cat /sys/class/graphics/fb0/virtual_size` is `5120,2880`
- 5K boot chain
  - the firmware drops the panel to single-stream 4K (EDID product `ae01`) when it loads a non-Apple EFI binary
  - Apple Hardware Diagnostics keeps dual-stream 5K, so `/boot/boot.efi` is Apple `diags.efi` (OCLP `payloads/Drivers/diags.efi`, sha256 in `install/.env`)
  - it chainloads the UKI at `/boot/System/Library/CoreServices/.diagnostics/Drivers/HardwareDrivers/Product.efi`
  - BootOrder: `Linux 5K` (`\boot.efi`), then `Linux Boot Manager` (systemd-boot)
  - refs: https://khronokernel.com/macos/2021/12/08/5K-UEFI.html, OCLP `efi_builder/firmware.py` `_dual_dp_handling`
- kernel updates rebuild the UKI and `/boot/initramfs-linux.img` via the mkinitcpio pacman hook, `/boot/boot.efi` is never touched
- UKI cmdline: `/etc/kernel/cmdline`, adds `module_blacklist=amdgpu quiet loglevel=3 consoleblank=0 vt.global_cursor_default=0`
- console: firmware framebuffer (simpledrm), no GPU acceleration, no backlight control
- tty1: `billboard-terminal.service`
  - cage, a kiosk Wayland compositor, owns the screen through a logind session on tty1 and shows the newest window fullscreen
  - foot in cage runs `cat` on the fifo `/run/billboard-terminal`, the mirror writes frames into it
  - the fifo comes from `/etc/tmpfiles.d/billboard-terminal.conf`, before sshd, so an early mirror never creates a plain file
  - `WLR_RENDERER=pixman`, simpledrm has no render node
  - `cage -d` stops foot drawing a title bar, which would cost a row
  - `/etc/billboard/foot.ini`: DejaVu Sans Mono 26px with 32px lines, 16x32 cells, 320x90
  - logs: `journalctl -u billboard-terminal`
- `show`
  - mpv `--vo=wlshm` in cage, over foot, foot is back when mpv exits
  - `--vo=drm` can't take the screen from cage, `--vo=gpu` fails without a GPU and drops frames on llvmpipe
  - check what is on screen by reading the plane framebuffer through libdrm
- audio: Cirrus CS4206, card `PCH`, boots muted at 0%; install unmutes and sets Master 60%, `alsa-restore.service` keeps it across reboots
- network: Broadcom BCM57766 `enp4s0f0`, networkd DHCP on `en*`; wifi Broadcom BCM4360 is not set up (needs `broadcom-wl`)
- power schedule: `systemctl list-timers display-off.timer`; `rtcwake -m off -s 120` should come back in 5K
