#!/bin/bash
set -euxo pipefail
cd "$(dirname "$0")"
. ../env.sh . IP ROOT_PASSWORD DISK

SSH=(ssh -i "$HOME/.ssh/$SSH_KEY_NAME" -o BatchMode=yes -o StrictHostKeyChecking=accept-new "root@$IP")
ssh-keygen -R "$IP" || true

{ set +x; } 2>/dev/null
REPORT=$("${SSH[@]}" bash -s -- "$DISK" internal < disk-report)
./confirm-erase "$DISK" "the machine at $IP" "$REPORT"
set -x

FILES=(env.sh install/.env install/install.sh install/show)
[ ! -f ../.env ] || FILES+=(.env)
tar -c -C .. "${FILES[@]}" -C "$HOME/.ssh" --transform "s|^$SSH_KEY_NAME\.pub\$|install/&|" "$SSH_KEY_NAME.pub" |
  "${SSH[@]}" 'tar -C /root -x &&
  systemd-run --unit=install -p StandardOutput=file:/root/install.log -p StandardError=file:/root/install.log /root/install/install.sh &&
  tail -n +1 -f --pid="$(systemctl show -p MainPID --value install)" /root/install.log | grep --line-buffered -v "% done"
  [ "$(systemctl show -p Result --value install)" = success ] && systemctl reboot'
ssh-keygen -R "$IP"
