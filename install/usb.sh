#!/bin/bash
set -euxo pipefail
cd "$(dirname "$0")"
. ../env.sh .

[ -f "$HOME/.ssh/$SSH_KEY_NAME" ] || ssh-keygen -t ed25519 -N '' -C 'billboard control' -f "$HOME/.ssh/$SSH_KEY_NAME"

USB=$1
{ set +x; } 2>/dev/null
REPORT=$(sudo ./disk-report "$USB" usb)
./confirm-erase "$USB" "this computer" "$REPORT"
set -x

W=$(mktemp -d)
curl -fL -o "$W/arch.iso" "$ISO_URL"
curl -fL -o "$W/arch.iso.sig" "$ISO_URL.sig"
gpg --dearmor < /usr/share/pacman/keyrings/archlinux.gpg > "$W/archlinux.kbx"
gpgv --keyring "$W/archlinux.kbx" "$W/arch.iso.sig" "$W/arch.iso"

sudo umount "$USB"?* 2>/dev/null || true
sudo dd if="$W/arch.iso" of="$USB" bs=4M conv=fsync oflag=direct status=progress
ISO_SECTORS=$(( ($(stat -c %s "$W/arch.iso") + 511) / 512 ))
START=$(( (ISO_SECTORS + 2047) / 2048 * 2048 ))
echo "start=$START, size=131072, type=c" | sudo sfdisk --no-reread -N 3 "$USB"
sudo blockdev --rereadpt "$USB"
sudo udevadm settle
sudo mkfs.fat -F 16 -n CIDATA "${USB}3"

mkdir "$W/cidata"
sudo mount "${USB}3" "$W/cidata"
printf '%s\n' '#cloud-config' "{\"disable_root\": false, \"users\": [{\"name\": \"root\", \"ssh_authorized_keys\": [\"$(cat "$HOME/.ssh/$SSH_KEY_NAME.pub")\"]}]}" | sudo tee "$W/cidata/user-data"
echo "{\"instance-id\": \"$HOST\"}" | sudo tee "$W/cidata/meta-data"
sudo umount "$W/cidata"
sync
rm -rf "$W"
