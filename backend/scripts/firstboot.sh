#!/usr/bin/env bash
# firstboot.sh — One-time VPS provisioning script for ancu365
#
# Run as root on a fresh Ubuntu 22.04 LTS VPS:
#   curl -fsSL https://raw.githubusercontent.com/<org>/ancu365-backend/main/scripts/firstboot.sh | bash
#   OR: scp scripts/firstboot.sh root@<vps>:/tmp/ && ssh root@<vps> bash /tmp/firstboot.sh
#
# Idempotent: each step checks before acting, safe to re-run.
#
# What this does:
#   1. System update + essential packages
#   2. Create ancu365 user + sudo + docker group
#   3. SSH key setup (copy root authorized_keys) + disable password auth
#   4. UFW firewall: allow only 22, 80, 443
#   5. 4 GB swap file
#   6. Install Docker + Docker Compose plugin
#   7. Clone repo to /opt/ancu365/ancu365-backend
#   8. Print next steps
#
# Security: run only once, then delete this file from the server.

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[firstboot]${NC} $*"; }
warn()  { echo -e "${YELLOW}[firstboot] WARNING:${NC} $*"; }
error() { echo -e "${RED}[firstboot] ERROR:${NC} $*" >&2; exit 1; }

# ── Must run as root ──────────────────────────────────────────────────────────
[[ "$(id -u)" -eq 0 ]] || error "Must run as root. Use: sudo bash $0"

# ── Config (override via environment if needed) ───────────────────────────────
APP_USER="${APP_USER:-ancu365}"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/ancu365}"
REPO_URL="${REPO_URL:-https://github.com/YOUR_ORG/ancu365-backend.git}"  # TODO: set real URL
SWAP_SIZE="${SWAP_SIZE:-4G}"

info "Starting firstboot.sh on $(hostname) at $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
info "App user: ${APP_USER} | Deploy dir: ${DEPLOY_DIR}"
echo ""

# ── Step 1: System update ─────────────────────────────────────────────────────
info "Step 1/8: System update..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
    curl wget git unzip gnupg2 ca-certificates \
    lsb-release software-properties-common \
    ufw logrotate htop ncdu
info "Step 1: done."

# ── Step 2: Create app user ───────────────────────────────────────────────────
info "Step 2/8: Creating user '${APP_USER}'..."
if id "${APP_USER}" &>/dev/null; then
    warn "User '${APP_USER}' already exists, skipping creation."
else
    adduser --disabled-password --gecos "" "${APP_USER}"
    info "User '${APP_USER}' created."
fi

# Add to sudo group
if ! id -nG "${APP_USER}" | grep -qw sudo; then
    usermod -aG sudo "${APP_USER}"
    info "Added ${APP_USER} to sudo group."
fi
info "Step 2: done."

# ── Step 3: SSH key setup + disable password auth ────────────────────────────
info "Step 3/8: Configuring SSH..."
APP_HOME="/home/${APP_USER}"
APP_SSH_DIR="${APP_HOME}/.ssh"

if [[ ! -f "${APP_SSH_DIR}/authorized_keys" ]]; then
    mkdir -p "${APP_SSH_DIR}"
    if [[ -f /root/.ssh/authorized_keys ]]; then
        cp /root/.ssh/authorized_keys "${APP_SSH_DIR}/authorized_keys"
        info "Copied root authorized_keys to ${APP_USER}."
    else
        warn "No /root/.ssh/authorized_keys found. You must manually add SSH keys for ${APP_USER}!"
        warn "Run: ssh-copy-id -i ~/.ssh/id_rsa.pub ${APP_USER}@$(hostname -I | awk '{print $1}')"
        # Don't fail — user may add keys manually
        touch "${APP_SSH_DIR}/authorized_keys"
    fi
    chmod 700 "${APP_SSH_DIR}"
    chmod 600 "${APP_SSH_DIR}/authorized_keys"
    chown -R "${APP_USER}:${APP_USER}" "${APP_SSH_DIR}"
fi

# Disable SSH password authentication
SSHD_CONF="/etc/ssh/sshd_config"
if grep -q "^PasswordAuthentication yes" "${SSHD_CONF}"; then
    sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' "${SSHD_CONF}"
    info "SSH password auth disabled."
elif grep -q "^#PasswordAuthentication" "${SSHD_CONF}"; then
    sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' "${SSHD_CONF}"
    info "SSH password auth set to no (was commented)."
else
    # Already 'no' or set differently — ensure it's present
    grep -q "^PasswordAuthentication no" "${SSHD_CONF}" || \
        echo "PasswordAuthentication no" >> "${SSHD_CONF}"
fi

# Also disable PermitRootLogin with password
sed -i 's/^PermitRootLogin yes/PermitRootLogin prohibit-password/' "${SSHD_CONF}" || true
sed -i 's/^#PermitRootLogin.*/PermitRootLogin prohibit-password/' "${SSHD_CONF}" || true

systemctl restart sshd
info "Step 3: done. SSH password auth disabled."

# ── Step 4: UFW firewall ──────────────────────────────────────────────────────
info "Step 4/8: Configuring UFW firewall..."
ufw --force reset > /dev/null 2>&1 || true
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment "SSH"
ufw allow 80/tcp comment "HTTP (Caddy ACME)"
ufw allow 443/tcp comment "HTTPS (Caddy)"
ufw --force enable
ufw status verbose
info "Step 4: done. UFW active: 22, 80, 443 open."

# ── Step 5: Swap file ─────────────────────────────────────────────────────────
info "Step 5/8: Configuring ${SWAP_SIZE} swap..."
if swapon --show | grep -q /swapfile; then
    warn "Swap /swapfile already active ($(swapon --show --noheadings --bytes | awk '{printf "%.0f GB", $3/1073741824}')), skipping."
else
    fallocate -l "${SWAP_SIZE}" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    # Persist across reboots
    if ! grep -q "/swapfile" /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    # Tune swappiness for server workload
    sysctl -w vm.swappiness=10 > /dev/null
    grep -q "^vm.swappiness" /etc/sysctl.conf \
        && sed -i 's/^vm.swappiness.*/vm.swappiness=10/' /etc/sysctl.conf \
        || echo 'vm.swappiness=10' >> /etc/sysctl.conf
    info "Swap ${SWAP_SIZE} created and enabled."
fi
free -h
info "Step 5: done."

# ── Step 6: Install Docker + Docker Compose ───────────────────────────────────
info "Step 6/8: Installing Docker..."
if command -v docker &>/dev/null; then
    warn "Docker already installed: $(docker --version). Skipping."
else
    curl -fsSL https://get.docker.com | sh
    info "Docker installed: $(docker --version)"
fi

# Ensure Docker Compose plugin is available
if ! docker compose version &>/dev/null; then
    apt-get install -y -qq docker-compose-plugin
fi
info "Docker Compose: $(docker compose version)"

# Add app user to docker group
if ! id -nG "${APP_USER}" | grep -qw docker; then
    usermod -aG docker "${APP_USER}"
    info "Added ${APP_USER} to docker group."
fi

# Enable Docker on boot
systemctl enable docker --quiet
info "Step 6: done."

# ── Step 7: Clone repo ────────────────────────────────────────────────────────
info "Step 7/8: Cloning repository..."
mkdir -p "${DEPLOY_DIR}"
chown -R "${APP_USER}:${APP_USER}" "${DEPLOY_DIR}"

if [[ -d "${DEPLOY_DIR}/ancu365-backend/.git" ]]; then
    warn "Repo already exists at ${DEPLOY_DIR}/ancu365-backend. Pulling latest..."
    sudo -u "${APP_USER}" git -C "${DEPLOY_DIR}/ancu365-backend" pull --ff-only || \
        warn "git pull failed — resolve manually."
else
    if [[ "$REPO_URL" == *"YOUR_ORG"* ]]; then
        warn "REPO_URL contains placeholder 'YOUR_ORG'. Skipping clone."
        warn "Run manually: git clone <your-repo-url> ${DEPLOY_DIR}/ancu365-backend"
    else
        sudo -u "${APP_USER}" git clone "${REPO_URL}" "${DEPLOY_DIR}/ancu365-backend"
        info "Repo cloned to ${DEPLOY_DIR}/ancu365-backend"
    fi
fi
info "Step 7: done."

# ── Step 8: Logrotate for backup log ─────────────────────────────────────────
info "Step 8/8: Configuring logrotate for backup logs..."
cat > /etc/logrotate.d/ancu365-backup <<'EOF'
/var/log/ancu365-backup.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    create 0640 ancu365 adm
}
EOF
touch /var/log/ancu365-backup.log
chown "${APP_USER}:adm" /var/log/ancu365-backup.log 2>/dev/null || true
info "Step 8: done."

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              firstboot.sh completed successfully             ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Next steps (run as ${APP_USER}):                            ║"
echo "║                                                              ║"
echo "║  1. Log in as ${APP_USER}:                                   ║"
echo "║     ssh ${APP_USER}@$(hostname -I | awk '{print $1}' 2>/dev/null || echo '<vps-ip>')"
echo "║                                                              ║"
echo "║  2. Set up .env:                                             ║"
echo "║     cd ${DEPLOY_DIR}/ancu365-backend                         ║"
echo "║     cp .env.example .env && nano .env                        ║"
echo "║     chmod 600 .env                                           ║"
echo "║                                                              ║"
echo "║  3. Boot the stack:                                          ║"
echo "║     make prod-up                                             ║"
echo "║                                                              ║"
echo "║  4. Install backup cron:                                     ║"
echo "║     sudo cp scripts/cron-backup /etc/cron.d/ancu365-backup   ║"
echo "║     sudo chmod 644 /etc/cron.d/ancu365-backup                ║"
echo "║                                                              ║"
echo "║  See: docs/deploy-runbook.md for full deploy procedure.      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
info "Done at $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
