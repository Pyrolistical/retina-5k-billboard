#!/bin/bash
set -euxo pipefail
cd "$(dirname "$0")"
. ../env.sh . IP ROOT_PASSWORD
case ${OFF_UTC:+off}${ON_UTC:+on} in
  ""|offon) ;;
  *) echo "set both OFF_UTC and ON_UTC, or neither" >&2; exit 1 ;;
esac

D=$DISK

blkdiscard -f "$D"
sgdisk -o -n1:0:+1G -t1:ef00 -c1:ESP -n2:0:0 -t2:8304 -c2:root "$D"
udevadm settle
mkfs.fat -F32 -n ESP "${D}1"
mkfs.ext4 -F -L root "${D}2"
mount "${D}2" /mnt
mount --mkdir -o fmask=0077,dmask=0077 "${D}1" /mnt/boot

pacstrap -K /mnt base linux linux-firmware intel-ucode openssh vim mpv cage foot ttf-dejavu alsa-utils efibootmgr
genfstab -U /mnt >> /mnt/etc/fstab
ROOT_UUID=$(blkid -s UUID -o value "${D}2")
CMDLINE="root=UUID=$ROOT_UUID rw quiet loglevel=3 consoleblank=0 vt.global_cursor_default=0"

echo "$HOST" > /mnt/etc/hostname
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /mnt/etc/localtime
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen
echo LANG=en_US.UTF-8 > /mnt/etc/locale.conf
printf '%s\n' 'PermitRootLogin prohibit-password' 'PasswordAuthentication no' 'KbdInteractiveAuthentication no' 'ClientAliveInterval 10' 'ClientAliveCountMax 3' > /mnt/etc/ssh/sshd_config.d/10-billboard.conf

cat > /mnt/etc/systemd/network/20-wired.network <<EOF
[Match]
Name=en*

[Network]
DHCP=yes
EOF

install -Dm600 "$SSH_KEY_NAME.pub" /mnt/root/.ssh/authorized_keys
install -m 755 show /mnt/usr/local/bin/show

mkdir -p /mnt/etc/billboard
cat > /mnt/etc/billboard/foot.ini <<'EOF'
[main]
font=DejaVu Sans Mono:pixelsize=26
line-height=32px
pad=0x0
EOF
echo 'p /run/billboard-terminal 0600 root root -' > /mnt/etc/tmpfiles.d/billboard-terminal.conf
cat > /mnt/etc/systemd/system/billboard-terminal.service <<'EOF'
[Unit]
Description=foot in cage on tty1, reads the mirror from /run/billboard-terminal
After=systemd-user-sessions.service
Conflicts=getty@tty1.service

[Service]
PAMName=login
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
StandardInput=tty-fail
StandardOutput=journal
StandardError=journal
UtmpIdentifier=tty1
UtmpMode=user
Environment=WLR_RENDERER=pixman
ExecStart=/usr/bin/cage -d -- foot --config=/etc/billboard/foot.ini sh -c 'exec cat 0<> /run/billboard-terminal'
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
systemctl --root=/mnt enable billboard-terminal

if [ -n "$OFF_UTC" ]; then
cat > /mnt/etc/systemd/system/display-off.service <<EOF
[Unit]
Description=power off at $OFF_UTC UTC, RTC wake at $ON_UTC UTC

[Service]
Type=oneshot
ExecStart=/bin/sh -c 't=\$(date -u -d $ON_UTC +%%s); [ \$\$t -gt \$(date +%%s) ] || t=\$\$((\$\$t + 86400)); exec rtcwake -u -m off -t \$\$t'
EOF
cat > /mnt/etc/systemd/system/display-off.timer <<EOF
[Unit]
Description=power off daily at $OFF_UTC UTC

[Timer]
OnCalendar=*-*-* $OFF_UTC:00 UTC

[Install]
WantedBy=timers.target
EOF
systemctl --root=/mnt enable display-off.timer
fi

HWD=/boot/System/Library/CoreServices/.diagnostics/Drivers/HardwareDrivers
mkdir -p "/mnt$HWD"
echo "$CMDLINE module_blacklist=amdgpu" > /mnt/etc/kernel/cmdline
echo "default_uki=\"$HWD/Product.efi\"" >> /mnt/etc/mkinitcpio.d/linux.preset

arch-chroot /mnt /bin/bash -euxo pipefail <<EOF
hwclock --systohc
locale-gen
echo root:$ROOT_PASSWORD | chpasswd
systemctl enable systemd-networkd systemd-resolved systemd-timesyncd sshd fstrim.timer systemd-boot-update
systemctl disable getty@tty1
amixer -q -c PCH sset Speaker 100% unmute
amixer -q -c PCH sset Headphone 100% unmute
amixer -q -c PCH sset PCM 100%
amixer -q -c PCH sset Master 60% unmute
alsactl store
mkinitcpio -P
EOF
ln -sf ../run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf

curl -fL -o /mnt/boot/boot.efi "$DIAGS_URL"
echo "$DIAGS_SHA256  /mnt/boot/boot.efi" | sha256sum -c

efibootmgr | grep -oE '^Boot[0-9A-F]{4}' | cut -c5- | grep -vx FFFF | while read -r n; do efibootmgr -q -b "$n" -B; done
bootctl --esp-path=/mnt/boot install
cat > /mnt/boot/loader/loader.conf <<EOF
default arch.conf
timeout 3
editor no
EOF
cat > /mnt/boot/loader/entries/arch.conf <<EOF
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options $CMDLINE
EOF
efibootmgr -q -c -d "$D" -p 1 -l '\boot.efi' -L 'Linux 5K'
N5K=$(efibootmgr | grep 'Linux 5K' | cut -c5-8)
NSD=$(efibootmgr | grep -E '^Boot[0-9A-F]{4}\* Linux Boot Manager' | cut -c5-8)
efibootmgr -q -o "$N5K,$NSD"
efibootmgr

umount -R /mnt
echo INSTALL_DONE
