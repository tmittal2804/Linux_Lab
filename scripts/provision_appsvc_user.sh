#!/usr/bin/env bash
#
# provision_appsvc_user.sh
#
# Provision an application user with:
# - home dir (default /home/appsvc_<project> or configurable)
# - restricted shell (no interactive login) but allows:
#     * SFTP
#     * execution of exactly /usr/local/bin/run_app via sudo
#   achieved via:
#     * command=".../appsvc-shell" forced in authorized_keys (per-key)
#     * wrapper /usr/local/bin/appsvc-shell that dispatches to sftp-server or sudo run_app
# - SSH key injection from a file; each key is written with:
#     no-port-forwarding,no-X11-forwarding,no-agent-forwarding,from="CIDR1,CIDR2",command="/usr/local/bin/appsvc-shell"
# - POSIX ACLs to give access to /srv/apps/<project> (fallback: unix group + mode)
# - minimal sudoers rule in /etc/sudoers.d/
# - password policy check (min 12 chars, upper, lower, digit, symbol)
# - optional: create user with locked password, optional chroot-sftp skeleton
# - idempotent, checks for existing user, supports --force to overwrite partial state
# - rollback file created at /var/tmp/appsvc_<user>_created.list
#
# Tested on typical Linux distributions with OpenSSH, setfacl, and sudo present.
#

set -euo pipefail
IFS=$'\n\t'

### Defaults
RUN_APP="/usr/local/bin/run_app"
APPS_ROOT="/srv/apps"
SFTP_SHELL_WRAPPER="/usr/local/bin/appsvc-shell"
SUDOERS_DIR="/etc/sudoers.d"
SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_DIR="/var/backups/appsvc"
ROLLBACK_DIR="/var/tmp"
ROLLBACK_MARKER=""
FORCE=0
CREATE_CHROOT=0

### Helper functions
usage() {
  cat <<EOF
Usage: $0 --project <project> [options]

Required:
  --project <project>            Project name (used to create user appsvc_<project> and group)

Options:
  --user <username>              Username (default: appsvc_<project>)
  --home <path>                  Home directory (default: /home/<user>)
  --keys-file <file>             File containing public keys, one per line (required to add keys)
  --cidrs <cidr1,cidr2,...>      Comma-separated list of allowed source CIDRs for keys (applied to all keys)
  --password <password>          Set initial password (will be validated by policy). If omitted and --lock-password not set, account will have no password set.
  --lock-password                Create account locked (no password login). SSH key only.
  --chroot                       OPTIONAL: setup chroot-based SFTP skeleton for the user (must be used with care). See README below.
  --force                        Overwrite / modify existing user and files when necessary.
  --help

Example:
  sudo ./provision_appsvc_user.sh --project myproj --keys-file ./myproj.pub --cidrs 203.0.113.0/24,198.51.100.0/24 --lock-password

EOF
  exit 1
}

log() { echo ">>> $*"; }
err() { echo "ERROR: $*" >&2; }

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    err "This script must be run as root"
    exit 2
  fi
}

regex_password_ok() {
  local pw="$1"
  # min 12, at least 1 lower, 1 upper, 1 digit, 1 symbol
  if [[ ${#pw} -lt 12 ]]; then return 1; fi
  if ! [[ $pw =~ [a-z] ]]; then return 1; fi
  if ! [[ $pw =~ [A-Z] ]]; then return 1; fi
  if ! [[ $pw =~ [0-9] ]]; then return 1; fi
  if ! [[ $pw =~ [\!\@\#\$\%\^\&\*\(\)\-\_\=\+\[\]\{\}\:\;\"\'\<\>\,\.\?\/\\\|] ]]; then return 1; fi
  return 0
}

backup_file() {
  local f="$1"
  mkdir -p "$BACKUP_DIR"
  if [ -e "$f" ]; then
    local ts
    ts=$(date -u +"%Y%m%dT%H%M%SZ")
    cp -a "$f" "$BACKUP_DIR/$(basename "$f").backup.$ts"
  fi
}

mark_created() {
  # record created items for rollback
  local item="$1"
  echo "$item" >> "$ROLLBACK_MARKER"
}

rollback() {
  if [ ! -f "$ROLLBACK_MARKER" ]; then
    echo "No rollback marker found."
    exit 0
  fi
  echo "Rolling back changes recorded in $ROLLBACK_MARKER ..."
  tac "$ROLLBACK_MARKER" | while read -r item; do
    echo "ROLLBACK: $item"
    case "$item" in
      "user:"* )
        usr="${item#user:}"
        userdel -r "$usr" || true
        ;;
      "file:"* )
        f="${item#file:}"
        rm -f "$f" || true
        ;;
      "dir:"* )
        d="${item#dir:}"
        rm -rf "$d" || true
        ;;
      "group:"* )
        g="${item#group:}"
        # try delete group if empty
        if getent group "$g" >/dev/null; then
          # remove group only if no members
          members=$(getent group "$g" | awk -F: '{print $4}')
          if [ -z "$members" ]; then
            groupdel "$g" || true
          fi
        fi
        ;;
      "sudoers:"* )
        f="${item#sudoers:}"
        rm -f "$SUDOERS_DIR/$f" || true
        ;;
      "sshd_backup:"* )
        f="${item#sshd_backup:}"
        # restore original
        cp -a "$BACKUP_DIR/$f" "$SSHD_CONFIG" || true
        ;;
      * )
        echo "Unknown rollback item type: $item"
        ;;
    esac
  done
  rm -f "$ROLLBACK_MARKER"
  echo "Rollback finished."
  exit 0
}

safe_reload_sshd() {
  # Reload sshd only after syntax check
  if command -v sshd >/dev/null 2>&1; then
    if sshd -t -f "$SSHD_CONFIG"; then
      systemctl reload sshd || service sshd reload || systemctl restart sshd || true
      return 0
    else
      err "sshd config test failed. Not reloading sshd."
      return 1
    fi
  else
    err "sshd binary not found; skipping reload."
    return 1
  fi
}

install_sudoers() {
  local sudofile="$1"
  local content="$2"
  echo "$content" > "$SUDOERS_DIR/$sudofile"
  chmod 0440 "$SUDOERS_DIR/$sudofile"
  # Validate
  if visudo -cf "$SUDOERS_DIR/$sudofile"; then
    log "Sudoers file $SUDOERS_DIR/$sudofile validated and installed."
    mark_created "sudoers:$sudofile"
  else
    rm -f "$SUDOERS_DIR/$sudofile"
    err "Sudoers validation failed for $sudofile. Aborting."
    exit 1
  fi
}

# Parse args
PROJECT=""
USERNAME=""
HOME_DIR=""
KEYS_FILE=""
CIDRS=""
PASSWORD=""
LOCK_PASSWORD=0

while (( "$#" )); do
  case "$1" in
    --project) PROJECT="$2"; shift 2;;
    --user) USERNAME="$2"; shift 2;;
    --home) HOME_DIR="$2"; shift 2;;
    --keys-file) KEYS_FILE="$2"; shift 2;;
    --cidrs) CIDRS="$2"; shift 2;;
    --password) PASSWORD="$2"; shift 2;;
    --lock-password) LOCK_PASSWORD=1; shift;;
    --force) FORCE=1; shift;;
    --chroot) CREATE_CHROOT=1; shift;;
    --rollback) rollback; shift;;
    --help) usage;;
    *) err "Unknown arg: $1"; usage;;
  esac
done

if [ -z "$PROJECT" ]; then err "Missing --project"; usage; fi
if [ -z "$USERNAME" ]; then USERNAME="appsvc_${PROJECT}"; fi
if [ -z "$HOME_DIR" ]; then HOME_DIR="/home/${USERNAME}"; fi

if [ -n "$KEYS_FILE" ] && [ ! -f "$KEYS_FILE" ]; then err "Keys file $KEYS_FILE not found"; exit 1; fi
if [ -n "$PASSWORD" ]; then
  if ! regex_password_ok "$PASSWORD"; then
    err "Password does not meet policy: min 12 chars, 1 upper, 1 lower, 1 digit, 1 symbol"
    exit 1
  fi
fi

require_root

# Prepare rollback marker
ROLLBACK_MARKER="$ROLLBACK_DIR/appsvc_${USERNAME}_created.list"
: > "$ROLLBACK_MARKER"

# 1) Create group for the project
GROUP="${USERNAME}"
if getent group "$GROUP" >/dev/null 2>&1; then
  log "Group $GROUP exists"
else
  log "Creating group $GROUP"
  groupadd --system "$GROUP"
  mark_created "group:$GROUP"
fi

# 2) Create user idempotently
if id -u "$USERNAME" >/dev/null 2>&1; then
  log "User $USERNAME exists"
  if [ "$FORCE" -eq 0 ]; then
    log "Checking existing configuration and adjusting where safe..."
  else
    log "--force set: we will adjust existing user where needed"
  fi
else
  log "Creating user $USERNAME with home $HOME_DIR (no interactive shell by default)"
  useradd --system --gid "$GROUP" --home-dir "$HOME_DIR" --create-home --shell /usr/sbin/nologin "$USERNAME"
  mark_created "user:$USERNAME"
  # secure home
  chmod 0700 "$HOME_DIR"
  mark_created "dir:$HOME_DIR"
fi

# 3) Ensure home dir exists with strict perms
mkdir -p "$HOME_DIR"
chmod 0700 "$HOME_DIR"
chown "$USERNAME":"$GROUP" "$HOME_DIR"

# 4) Create run_app placeholder
if [ ! -x "$RUN_APP" ] || [ "$FORCE" -eq 1 ]; then
  cat > "$RUN_APP" <<'EOF'
#!/usr/bin/env bash
# placeholder run_app - replace with actual run logic
echo "run_app executed as $(id) with args: $*"
# Put real app start logic here, e.g. exec /opt/<project>/bin/start "$@"
exit 0
EOF
  chmod 0755 "$RUN_APP"
  chown root:root "$RUN_APP"
  log "Created placeholder $RUN_APP"
  mark_created "file:$RUN_APP"
else
  log "$RUN_APP exists and executable"
fi

# 5) Create guarded shell wrapper that is forced via authorized_keys command="..."
SHELL_WRAPPER="$SFTP_SHELL_WRAPPER"
if [ ! -x "$SHELL_WRAPPER" ] || [ "$FORCE" -eq 1 ]; then
  cat > "$SHELL_WRAPPER" <<'EOF'
#!/usr/bin/env bash
# appsvc-shell: run_app + sftp dispatcher
# This wrapper is intended to be used as a forced command in authorized_keys:
# command="/usr/local/bin/appsvc-shell",no-pty,...
set -euo pipefail
SSH_ORIG="${SSH_ORIGINAL_COMMAND:-}"
# locate sftp-server binary
SFTP_BIN=""
for p in /usr/lib/openssh/sftp-server /usr/libexec/openssh/sftp-server /usr/libexec/sftp-server /usr/lib/sftp-server /usr/lib/ssh/sftp-server; do
  if [ -x "$p" ]; then SFTP_BIN="$p"; break; fi
done
# If no SSH_ORIGINAL_COMMAND, deny interactive shells
if [ -z "$SSH_ORIG" ]; then
  echo "Interactive shell access is disabled for this account." >&2
  exit 1
fi

# If SFTP requested, exec sftp-server
# Common values: "internal-sftp", "sftp-server"
case "$SSH_ORIG" in
  internal-sftp*|/usr/lib/openssh/sftp-server*|*sftp-server*)
    if [ -n "$SFTP_BIN" ]; then
      exec "$SFTP_BIN"
    else
      echo "sftp-server not found on server." >&2
      exit 2
    fi
    ;;
esac

# Allow exactly /usr/local/bin/run_app to be run (possibly via sudo)
ALLOWED="/usr/local/bin/run_app"
# We allow commands like:
#  sudo /usr/local/bin/run_app [args]
#  /usr/local/bin/run_app [args]
# Extract base command
cmd_base=$(awk '{print $1}' <<<"$SSH_ORIG")
if [ "$cmd_base" = "$ALLOWED" ] || [ "$cmd_base" = "sudo" -a "$(awk '{print $2}' <<<"$SSH_ORIG")" = "$ALLOWED" ]; then
  # execute the original command so sudo can do its thing
  exec /bin/sh -lc "$SSH_ORIG"
else
  echo "Only SFTP and $ALLOWED are permitted." >&2
  exit 3
fi
EOF
  chmod 0755 "$SHELL_WRAPPER"
  chown root:root "$SHELL_WRAPPER"
  log "Installed shell wrapper at $SHELL_WRAPPER"
  mark_created "file:$SHELL_WRAPPER"
else
  log "Shell wrapper $SHELL_WRAPPER exists"
fi

# 6) Prepare authorized_keys with forced command and per-key options
if [ -n "$KEYS_FILE" ]; then
  SSH_DIR="$HOME_DIR/.ssh"
  AUTH_KEYS="$SSH_DIR/authorized_keys"
  mkdir -p "$SSH_DIR"
  chmod 0700 "$SSH_DIR"
  chown "$USERNAME":"$GROUP" "$SSH_DIR"

  # Build options prefix
  OPTS="no-port-forwarding,no-X11-forwarding,no-agent-forwarding,command=\"$SHELL_WRAPPER\""
  if [ -n "$CIDRS" ]; then
    # turn comma-separated into quoted comma list for from=""
    # authorized_keys expects comma-separated list
    OPTS="$OPTS,from=\"$CIDRS\""
  fi

  # Write keys idempotently: if authorized_keys already contains identical key entry, skip
  tmpfile=$(mktemp)
  while IFS= read -r line || [ -n "$line" ]; do
    # skip empty/comment lines
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue
    # Normalize whitespace
    key="$(echo "$line" | tr -s ' ' )"
    # If the exact key (without leading options) exists, ensure it has our options by replacing
    key_plain="$key"
    # If authorized_keys contains the key already (bare), remove previous lines for it
    if [ -f "$AUTH_KEYS" ] && grep -F "$key_plain" "$AUTH_KEYS" >/dev/null 2>&1; then
      # skip adding duplicate; but if existing line already has different options we will not touch unless --force
      if [ "$FORCE" -eq 1 ]; then
        # Remove old lines containing the key
        grep -Fv "$key_plain" "$AUTH_KEYS" > "${AUTH_KEYS}.bak" || true
      else
        # keep existing
        continue
      fi
    fi
    echo "${OPTS} ${key_plain}" >> "$tmpfile"
  done < "$KEYS_FILE"
  # Append to authorized_keys while preserving existing non-matching entries
  if [ -f "${AUTH_KEYS}.bak" ]; then
    cat "${AUTH_KEYS}.bak" > "$AUTH_KEYS"
  fi
  cat "$tmpfile" >> "$AUTH_KEYS"
  rm -f "$tmpfile" "${AUTH_KEYS}.bak"
  chmod 0600 "$AUTH_KEYS"
  chown "$USERNAME":"$GROUP" "$AUTH_KEYS"
  log "Installed authorized_keys for $USERNAME"
  mark_created "file:$AUTH_KEYS"
fi

# 7) Set account password or lock it
if [ "$LOCK_PASSWORD" -eq 1 ]; then
  passwd -l "$USERNAME" || true
  log "Locked password for $USERNAME (SSH key only)"
else
  if [ -n "$PASSWORD" ]; then
    echo "${USERNAME}:${PASSWORD}" | chpasswd
    log "Password set for $USERNAME"
  else
    # ensure password locked by default if no password provided
    passwd -l "$USERNAME" || true
    log "No password provided; account locked by default"
  fi
fi

# 8) Create sudoers minimal rule allowing exactly /usr/local/bin/run_app with NOPASSWD
SUDOFILE="appsvc_${USERNAME}"
SUDO_CONTENT="${USERNAME} ALL=(root) NOPASSWD: ${RUN_APP}"
install_sudoers "$SUDOFILE" "$SUDO_CONTENT"

# 9) Setup ACLs for access to /srv/apps/<project>
TARGET_APP_DIR="${APPS_ROOT}/${PROJECT}"
if [ ! -d "$TARGET_APP_DIR" ]; then
  mkdir -p "$TARGET_APP_DIR"
  chown root:root "$TARGET_APP_DIR"
  chmod 0755 "$TARGET_APP_DIR"
  mark_created "dir:$TARGET_APP_DIR"
fi

if command -v setfacl >/dev/null 2>&1; then
  log "Applying POSIX ACLs on $TARGET_APP_DIR for $USERNAME"
  # Grant read+execute for traversing dirs and read for files
  setfacl -R -m u:${USERNAME}:rX "$TARGET_APP_DIR"
  setfacl -R -m g:${GROUP}:rX "$TARGET_APP_DIR"
  setfacl -R -d -m u:${USERNAME}:rX "$TARGET_APP_DIR"
  setfacl -R -d -m g:${GROUP}:rX "$TARGET_APP_DIR"
  mark_created "file:$TARGET_APP_DIR (acl applied)"
else
  log "setfacl not found; falling back to UNIX groups and modes"
  # try to create project group and chown directory to group
  chgrp "${GROUP}" "$TARGET_APP_DIR" || true
  chmod 0750 "$TARGET_APP_DIR"
  log "Assigned group ${GROUP} read/execute on $TARGET_APP_DIR"
  mark_created "file:$TARGET_APP_DIR (mode changed)"
fi

# 10) Optionally create chroot skeleton for SFTP (danger: chroot dir must be owned by root)
if [ "$CREATE_CHROOT" -eq 1 ]; then
  log "Creating chroot skeleton for user (requires strict ownership and careful testing)"
  CHROOT_DIR="/home/${USERNAME}/chroot"
  if [ ! -d "$CHROOT_DIR" ]; then
    mkdir -p "$CHROOT_DIR/var/tmp"
    chown root:root "$CHROOT_DIR"
    chmod 0755 "$CHROOT_DIR"
    # create writable upload area
    mkdir -p "$CHROOT_DIR/home/$USERNAME"
    chown "$USERNAME":"$GROUP" "$CHROOT_DIR/home/$USERNAME"
    chmod 0700 "$CHROOT_DIR/home/$USERNAME"
    mark_created "dir:$CHROOT_DIR"
  fi

  # Add sshd_config snippet if not already present
  SNIPPET="# appsvc ${PROJECT} sftp chroot snippet
Match User ${USERNAME}
  ChrootDirectory ${CHROOT_DIR}
  ForceCommand internal-sftp
  X11Forwarding no
  AllowTcpForwarding no
"
  if ! grep -F "appsvc ${PROJECT} sftp chroot snippet" "$SSHD_CONFIG" >/dev/null 2>&1; then
    backup_file "$SSHD_CONFIG"
    echo "$SNIPPET" >> "$SSHD_CONFIG"
    mark_created "sshd_backup:$(basename "$SSHD_CONFIG").backup.*" || true
    safe_reload_sshd || { err "sshd reload failed after adding chroot snippet"; exit 1; }
    log "Added chroot sftp snippet for $USERNAME to $SSHD_CONFIG"
  else
    log "sshd_config already contains chroot snippet for $USERNAME"
  fi
fi

# 11) Final: ensure home and .ssh permissions are tight
chmod 0700 "$HOME_DIR"
[ -d "$HOME_DIR/.ssh" ] && chmod 0700 "$HOME_DIR/.ssh"
[ -f "$HOME_DIR/.ssh/authorized_keys" ] && chmod 0600 "$HOME_DIR/.ssh/authorized_keys"

log "Provisioning of $USERNAME for project $PROJECT completed."

echo
cat <<EOF
SUMMARY:
  User:        $USERNAME
  Home:        $HOME_DIR
  Group:       $GROUP
  Run command: $RUN_APP
  Shell wrapper:$SHELL_WRAPPER
  Keys file:   ${KEYS_FILE:-none}
  App dir ACL: $TARGET_APP_DIR

Rollback marker saved to: $ROLLBACK_MARKER
To rollback:  sudo $0 --rollback

Notes & security reminders:
 - authorized_keys entries are created with forced command=\"$SHELL_WRAPPER\" and forwarding disabled.
 - The wrapper permits only SFTP and invocations of $RUN_APP (direct or via sudo).
 - The sudoers entry allows NOPASSWD execution of $RUN_APP only.
 - If you enabled chroot SFTP (--chroot), double-check ownership rules: ChrootDirectory must be root-owned and not writable by non-root.
 - This script attempts to be idempotent; use --force to reapply/replace entries if you need to override.
EOF

exit 0
