#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# AniwatchTvdl — One-Command Setup for Amazon Linux 2023 (ARM64)
# ═══════════════════════════════════════════════════════════════════
#
# USAGE:
#   curl -fsSL https://raw.githubusercontent.com/<YOUR_USER>/setup.sh | sudo bash
#       — or —
#   sudo bash setup.sh
#
# This script:
#   1. Installs Docker on a bare Amazon Linux 2023 (aarch64)
#   2. Clones the AniwatchTvdl repo
#   3. Fixes the Dockerfile for ARM64 compatibility
#   4. Creates a .env template for your Telegram bot credentials
#   5. Builds & runs the container
#
# Requirements: root/sudo access, internet connection
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Color helpers ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Sanity checks ────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "Please run as root:  sudo bash $0"

info "Detecting system..."
ARCH=$(uname -m)
info "  Architecture: ${BOLD}${ARCH}${NC}"

if [[ "$ARCH" != "aarch64" && "$ARCH" != "arm64" ]]; then
    warn "Expected aarch64/arm64, detected ${ARCH}. Proceeding anyway..."
fi

# ── Step 1: Install essential tools ──────────────────────────────
info "Step 1/6 — Installing essential tools (git, tar, curl)..."
dnf install -y git tar curl gzip >/dev/null 2>&1 || yum install -y git tar curl gzip >/dev/null 2>&1
success "Essential tools installed"

# ── Step 2: Install Docker ───────────────────────────────────────
info "Step 2/6 — Installing Docker..."
if command -v docker &>/dev/null; then
    success "Docker already installed: $(docker --version)"
else
    # Amazon Linux 2023 method
    dnf install -y docker >/dev/null 2>&1 || {
        warn "dnf docker failed, trying amazon-linux-extras..."
        amazon-linux-extras install -y docker >/dev/null 2>&1 || {
            warn "Trying direct install from get.docker.com..."
            curl -fsSL https://get.docker.com | sh
        }
    }
    success "Docker installed: $(docker --version)"
fi

# Start & enable Docker
systemctl start docker 2>/dev/null || true
systemctl enable docker 2>/dev/null || true
success "Docker service started & enabled"

# ── Step 3: Clone the repository ─────────────────────────────────
WORK_DIR="/opt/AniwatchTvdl"
info "Step 3/6 — Cloning repository to ${WORK_DIR}..."

if [[ -d "${WORK_DIR}" ]]; then
    warn "Directory ${WORK_DIR} already exists — pulling latest changes"
    cd "${WORK_DIR}" && git pull --ff-only 2>/dev/null || true
else
    git clone https://github.com/abhinai2244/AniwatchTvdl.git "${WORK_DIR}"
fi
cd "${WORK_DIR}"
success "Repository cloned"

# ── Step 4: Write the fixed ARM64 Dockerfile ─────────────────────
info "Step 4/6 — Writing ARM64-optimized Dockerfile..."

cat > "${WORK_DIR}/Dockerfile" << 'DOCKERFILE_EOF'
# ─────────────────────────────────────────────────────────────────
# AniwatchTvdl (Cantarella Bot) — ARM64-optimized Dockerfile
# Targets: Amazon Linux 2023 / ARM64 (Graviton) / 1GB RAM / 10GB SSD
# ─────────────────────────────────────────────────────────────────

# Stage 1: Build N_m3u8DL-RE from source for linux-arm64
FROM --platform=linux/arm64 mcr.microsoft.com/dotnet/sdk:8.0-bookworm-slim AS m3u8build

RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/nilaoda/N_m3u8DL-RE.git /build

WORKDIR /build/src/N_m3u8DL-RE

RUN dotnet publish -c Release -r linux-arm64 --self-contained true \
    -p:PublishSingleFile=true -p:PublishTrimmed=true \
    -o /out

# ─────────────────────────────────────────────────────────────────
# Stage 2: Final runtime image — kept small for 10GB SSD
# ─────────────────────────────────────────────────────────────────
FROM --platform=linux/arm64 python:3.11-slim-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg \
        libicu72 \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

COPY --from=m3u8build /out/N_m3u8DL-RE /usr/local/bin/N_m3u8DL-RE
RUN chmod +x /usr/local/bin/N_m3u8DL-RE

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN mkdir -p /app/binary && \
    ln -sf /usr/local/bin/N_m3u8DL-RE /app/binary/N_m3u8DL-RE

CMD ["python3", "-m", "cantarella"]
DOCKERFILE_EOF

success "Dockerfile written"

# ── Step 5: Create .env template ─────────────────────────────────
info "Step 5/6 — Setting up environment configuration..."

if [[ ! -f "${WORK_DIR}/.env" ]]; then
    cat > "${WORK_DIR}/.env" << 'ENV_EOF'
# ═══════════════════════════════════════════════════════════
# AniwatchTvdl (Cantarella Bot) — Environment Configuration
# ═══════════════════════════════════════════════════════════
# Get API_ID & API_HASH from https://my.telegram.org
# Get BOT_TOKEN from @BotFather on Telegram
# Get MONGO_URL from https://www.mongodb.com/atlas (free tier)
# ═══════════════════════════════════════════════════════════

API_ID=
API_HASH=
BOT_TOKEN=
OWNER_ID=
MONGO_URL=
MONGO_NAME=cantarellabots
BOT_USERNAME=
LOG_CHANNEL=
MAIN_CHANNEL=
TARGET_CHAT_ID=
SET_INTERVAL=60
ADMIN_URL=@V_Sbotmaker
FSUB_PIC=
ENV_EOF

    warn "╔══════════════════════════════════════════════════════════╗"
    warn "║  .env file created at: ${WORK_DIR}/.env                 ║"
    warn "║  You MUST edit it with your Telegram credentials        ║"
    warn "║  before starting the bot!                               ║"
    warn "║                                                         ║"
    warn "║  Run:  nano ${WORK_DIR}/.env                            ║"
    warn "╚══════════════════════════════════════════════════════════╝"
else
    success ".env already exists — keeping your existing configuration"
fi

# ── Step 6: Build & Run ──────────────────────────────────────────
info "Step 6/6 — Building Docker image (this may take 5-15 min on ARM64)..."

# Enable Docker BuildKit for faster multi-stage builds
export DOCKER_BUILDKIT=1

# Configure Docker to limit memory usage during build (important for 1GB RAM)
# Add swap if not already present
if [[ $(swapon --show | wc -l) -le 1 ]]; then
    info "Adding 1GB swap file to help with build (1GB RAM is tight)..."
    if [[ ! -f /swapfile ]]; then
        dd if=/dev/zero of=/swapfile bs=1M count=1024 status=progress 2>/dev/null || true
        chmod 600 /swapfile
        mkswap /swapfile >/dev/null 2>&1
    fi
    swapon /swapfile 2>/dev/null || true
    success "Swap enabled"
fi

# Stop any existing container
docker stop aniwatchtv 2>/dev/null || true
docker rm aniwatchtv 2>/dev/null || true

# Build the image
docker build -t aniwatchtv:latest "${WORK_DIR}"

success "Docker image built successfully!"

# Check if .env has been configured
if grep -q "^API_ID=$" "${WORK_DIR}/.env" 2>/dev/null; then
    echo ""
    warn "═══════════════════════════════════════════════════════════"
    warn " .env is NOT configured yet!"
    warn " Edit it first:   nano ${WORK_DIR}/.env"
    warn " Then start bot:  docker run -d --name aniwatchtv \\"
    warn "                    --env-file ${WORK_DIR}/.env \\"
    warn "                    --restart unless-stopped \\"
    warn "                    --memory=768m \\"
    warn "                    aniwatchtv:latest"
    warn "═══════════════════════════════════════════════════════════"
else
    info "Starting the bot container..."
    docker run -d \
        --name aniwatchtv \
        --env-file "${WORK_DIR}/.env" \
        --restart unless-stopped \
        --memory=768m \
        aniwatchtv:latest

    success "Bot is running! Check logs with:  docker logs -f aniwatchtv"
fi

echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✅ AniwatchTvdl setup complete!${NC}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}Useful commands:${NC}"
echo -e "    docker logs -f aniwatchtv      — View live logs"
echo -e "    docker restart aniwatchtv      — Restart the bot"
echo -e "    docker stop aniwatchtv         — Stop the bot"
echo -e "    docker start aniwatchtv        — Start the bot"
echo -e "    docker system prune -af        — Clean up disk space"
echo ""
