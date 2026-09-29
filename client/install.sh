#!/bin/bash
set -euxo pipefail
HERE=$(dirname "$(realpath "$0")")
. "$HERE/../env.sh" "$HERE" IP WINDOW
if [ -z "$SESSION" ]; then
  mapfile -t SESSIONS < <(tmux list-sessions -F '#{session_name}' | grep -vx -e billboard -e billboard-render)
  [ ${#SESSIONS[@]} -eq 1 ] || { echo "set SESSION in $ENV_ROOT/.env, tmux sessions: ${SESSIONS[*]}" >&2; exit 1; }
  SESSION=${SESSIONS[0]}
  echo "SESSION=$SESSION" >> "$ENV_ROOT/.env"
fi
U=$HOME/.config/systemd/user
mkdir -p "$U"

cat > "$U/billboard-mirror.service" <<EOF
[Unit]
Description=mirror tmux window $SESSION:$WINDOW to $IP foot
StartLimitIntervalSec=0

[Service]
ExecStart=$HERE/mirror
Restart=always
RestartSec=2
RestartSteps=5
RestartMaxDelaySec=60

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now billboard-mirror
loginctl enable-linger "$USER"
