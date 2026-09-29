ENV_ROOT=$(dirname "${BASH_SOURCE[0]}")
[ ! -f "$ENV_ROOT/.env" ] || . "$ENV_ROOT/.env"
ENV_DIR=$(sed -E 's/^([A-Za-z_][A-Za-z0-9_]*)=$/\1=${\1:-}/' "$1/.env")
eval "$ENV_DIR"
for ENV_KEY in "${@:2}"; do
  [ -n "${!ENV_KEY:-}" ] || { echo "set $ENV_KEY in $1/.env or $ENV_ROOT/.env" >&2; exit 1; }
done
