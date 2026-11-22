#!/usr/bin/env bash
set -Eeuo pipefail

DOMAIN="fuckrkn.arira.site"
INSTALLER_URL="https://github.com/bivlked/amneziawg-installer/releases/latest/download/install_amneziawg_en.sh"

MOBILE=0
for arg in "$@"; do
  case "$arg" in
    --mobile) MOBILE=1 ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Usage: sudo bash $0 [--mobile]" >&2
      exit 2
      ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo: sudo bash $0 [--mobile]" >&2
  exit 1
fi

if ! getent ahostsv4 "$DOMAIN" >/dev/null; then
  echo "$DOMAIN does not resolve. Set its DNS record to this server's public IP first." >&2
  exit 1
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

curl -fsSL "$INSTALLER_URL" -o "$tmp"
chmod 700 "$tmp"

# Install the server. Apply the installer's mobile preset only when requested.
if (( MOBILE )); then
  bash "$tmp" --mobile
else
  bash "$tmp"
fi

CFG="/root/awg/awgsetup_cfg.init"
if [[ ! -f "$CFG" ]]; then
  echo "Installer finished, but $CFG was not found; cannot configure the client template." >&2
  exit 1
fi

if grep -qE '^[[:space:]]*AWG_ENDPOINT=' "$CFG"; then
  sed -i -E "s|^[[:space:]]*AWG_ENDPOINT=.*|AWG_ENDPOINT=\"${DOMAIN}\"|" "$CFG"
else
  printf '\nAWG_ENDPOINT="%s"\n' "$DOMAIN" >> "$CFG"
fi

echo "Set AWG_ENDPOINT in $CFG to $DOMAIN."
if (( MOBILE )); then
  echo "Installed with the mobile preset."
fi
echo "Check the installer's expected endpoint format/port before creating clients."