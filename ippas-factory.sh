#!/bin/bash
# ippas-factory.sh - the one command a technician runs on a fresh Debian 12 box, as root:
#
#   wget -qO- https://raw.githubusercontent.com/Elpro-Energy/ippas-factory/main/ippas-factory.sh | bash
#
# (or: curl -fsSL <same URL> | bash). Public on purpose: it holds no secrets.
#
# First run: asks for the GitHub read token (hidden, from the keyboard even when piped), clones the
# private IP-PAS repo at the release tag with a throwaway askpass helper (no token in .git/config),
# and installs + starts ippas-factory-resume.service, which runs factory/factory-install.sh --reboot
# now and again after every reboot until the box reaches FACTORY OK. The install does not depend on
# this SSH session: Ctrl-C only stops watching. Running the same line again shows the progress.
#
# Env: IPPAS_REF   tag or branch to clone (default below; a test can use a branch name)

set -euo pipefail

IPPAS_REF=${IPPAS_REF:-v1.0.0-rc.2}
REPO_URL=https://github.com/Elpro-Energy/ippas-onprem.git
APP_USER=sangoma
REPO=/home/$APP_USER/ippas-onprem
TOKEN_FILE=/root/.config/ippas/github-read-token
STATE_DIR=/var/lib/ippas-factory
LOG_DIR=/var/log/ippas-factory
UNIT=ippas-factory-resume.service
UNIT_FILE=/etc/systemd/system/$UNIT

say() { printf 'ippas-factory: %s\n' "$*"; }
die() { printf 'ippas-factory: ERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root (su -, then the same command)"
case $IPPAS_REF in ''|*[!A-Za-z0-9._/+-]*) die "IPPAS_REF has unsafe characters" ;; esac

# Show progress of an install that is already running or finished, then stop.
watch_progress() {
    say "the install runs in the background ($UNIT); Ctrl-C only stops watching"
    say "full logs: $LOG_DIR/  (after a reboot, run this same command again to watch)"
    exec journalctl -f -n 40 -o cat -u "$UNIT"
}

if [ -e "$STATE_DIR/factory.done" ]; then
    say "this box is finished: $(cat "$STATE_DIR/factory.done")"
    say "self-check only: $REPO/factory/factory-install.sh --check"
    exit 0
fi
if systemctl is-active --quiet "$UNIT" 2>/dev/null; then
    watch_progress
fi

need=()
for p in git ca-certificates; do
    dpkg-query -W -f='${db:Status-Abbrev}' "$p" 2>/dev/null | grep -q '^ii' || need+=("$p")
done
if [ "${#need[@]}" -gt 0 ]; then
    say "installing ${need[*]}"
    apt-get -o Acquire::Retries=3 update
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${need[@]}"
fi

if [ ! -s "$TOKEN_FILE" ]; then
    [ -r /dev/tty ] || die "no keyboard to read the token from; run it from an interactive session"
    install -d -m 700 "${TOKEN_FILE%/*}"
    read -rsp 'GitHub read token (input hidden): ' T </dev/tty; echo
    T=$(printf '%s' "$T" | tr -d ' \r\n')
    [[ $T =~ ^github_pat_[A-Za-z0-9_]+$ ]] || die "that does not look like a GitHub token (github_pat_...)"
    (umask 077; printf '%s' "$T" >"$TOKEN_FILE")
    unset T
    say "token saved to $TOKEN_FILE (mode 600)"
fi

id -u "$APP_USER" >/dev/null 2>&1 || useradd -m -s /bin/bash "$APP_USER"

if [ ! -d "$REPO/.git" ]; then
    [ ! -e "$REPO" ] || die "$REPO exists but is not a git checkout; move it away first"
    A=$(mktemp -d)
    trap 'rm -rf "$A"' EXIT
    printf '#!/bin/sh\ncase "$1" in Username*) echo x-access-token ;; *) cat %s ;; esac\n' "$TOKEN_FILE" >"$A/askpass"
    chmod 700 "$A/askpass"
    say "cloning $IPPAS_REF"
    GIT_ASKPASS="$A/askpass" GIT_TERMINAL_PROMPT=0 \
        git clone --depth 1 --branch "$IPPAS_REF" "$REPO_URL" "$REPO" \
        || die "clone failed (wrong or expired token, or $IPPAS_REF does not exist)"
    rm -rf "$A"
    trap - EXIT
    chown -R "$APP_USER:$APP_USER" "$REPO"
fi
if grep -q github_pat_ "$REPO/.git/config"; then die "token found in $REPO/.git/config"; fi
[ -x "$REPO/factory/factory-install.sh" ] || die "$REPO/factory/factory-install.sh missing"

cat >"$UNIT_FILE.tmp" <<EOF
[Unit]
Description=IP-PAS factory install (runs at every boot until the box is finished)
Wants=network-online.target
After=network-online.target
ConditionPathExists=!$STATE_DIR/factory.done

[Service]
Type=oneshot
Environment=HOME=/root TERM=dumb
ExecStart=$REPO/factory/factory-install.sh --reboot
TimeoutStartSec=infinity
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
EOF
mv -f "$UNIT_FILE.tmp" "$UNIT_FILE"
systemctl daemon-reload
systemctl enable "$UNIT" >/dev/null 2>&1
systemctl start --no-block "$UNIT"
say "started $UNIT (it resumes by itself after each reboot; about 80 min and two reboots in all)"
watch_progress
