#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# AniwatchTvdl — One-Command Setup for Amazon Linux 2023 (ARM64)
# ═══════════════════════════════════════════════════════════════════
#
# USAGE:
#   sudo bash setup.sh
#       — or —
#   sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/Alaxroy121/solid-system/main/setup.sh)"
#
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Color helpers ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

banner()  { echo -e "\n${CYAN}${BOLD}══════════════════════════════════════════════════════${NC}"; echo -e "${CYAN}${BOLD}  $*${NC}"; echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════${NC}\n"; }
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[✔ OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()    { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }

# ── Sanity checks ────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && fail "Please run as root:  sudo bash $0"

banner "AniwatchTvdl — ARM64 Docker Setup"
info "Architecture: ${BOLD}$(uname -m)${NC}"
info "OS:           ${BOLD}$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || uname -s)${NC}"
info "RAM:          ${BOLD}$(free -h | awk '/Mem:/{print $2}')${NC}"
info "Disk:         ${BOLD}$(df -h / | awk 'NR==2{print $4}') free${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════
banner "Step 1/6 — Installing essential tools"
# ═══════════════════════════════════════════════════════════════════
info "Running: dnf install -y --allowerasing git tar gzip ..."
info "(Using --allowerasing to resolve curl-minimal vs curl conflict)"
echo ""
dnf install -y --allowerasing git tar gzip
echo ""
success "Essential tools installed"

# ═══════════════════════════════════════════════════════════════════
banner "Step 2/6 — Installing Docker"
# ═══════════════════════════════════════════════════════════════════
if command -v docker &>/dev/null; then
    success "Docker already installed: $(docker --version)"
else
    info "Running: dnf install -y docker ..."
    echo ""
    dnf install -y docker || {
        warn "dnf docker failed, trying get.docker.com ..."
        curl -fsSL https://get.docker.com | sh
    }
    echo ""
    success "Docker installed: $(docker --version)"
fi

info "Starting Docker service..."
systemctl start docker 2>/dev/null || true
systemctl enable docker 2>/dev/null || true
success "Docker service is running"

# ═══════════════════════════════════════════════════════════════════
banner "Step 3/6 — Cloning AniwatchTvdl repository"
# ═══════════════════════════════════════════════════════════════════
WORK_DIR="/opt/AniwatchTvdl"

if [[ -d "${WORK_DIR}" ]]; then
    warn "Directory ${WORK_DIR} already exists — pulling latest"
    cd "${WORK_DIR}"
    git pull --ff-only || true
else
    info "Running: git clone https://github.com/abhinai2244/AniwatchTvdl.git ${WORK_DIR}"
    echo ""
    git clone https://github.com/abhinai2244/AniwatchTvdl.git "${WORK_DIR}"
fi
cd "${WORK_DIR}"
echo ""
success "Repository ready at ${WORK_DIR}"
info "Files:"
ls -la "${WORK_DIR}/"

# ═══════════════════════════════════════════════════════════════════
banner "Step 4/6 — Writing ARM64-optimized Dockerfile"
# ═══════════════════════════════════════════════════════════════════
info "The original Dockerfile is broken (x64 only + incomplete)"
info "Writing fixed multi-stage ARM64 Dockerfile..."

cat > "${WORK_DIR}/Dockerfile" << 'DOCKERFILE_EOF'
# ─────────────────────────────────────────────────────────────────
# AniwatchTvdl (Cantarella Bot) — ARM64-optimized Dockerfile
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

# Stage 2: Final runtime image
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

echo ""
success "Dockerfile written"
info "Preview:"
cat "${WORK_DIR}/Dockerfile"

# ═══════════════════════════════════════════════════════════════════
banner "Step 5/6 — Environment configuration"
# ═══════════════════════════════════════════════════════════════════
if [[ ! -f "${WORK_DIR}/.env" ]]; then
    cat > "${WORK_DIR}/.env" << 'ENV_EOF'
# ═══════════════════════════════════════════════════════════
# AniwatchTvdl — Fill in your Telegram credentials below
# ═══════════════════════════════════════════════════════════
# API_ID & API_HASH → https://my.telegram.org
# BOT_TOKEN        → @BotFather on Telegram
# MONGO_URL        → https://www.mongodb.com/atlas (free)
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

    echo ""
    warn "┌─────────────────────────────────────────────────────┐"
    warn "│  .env file created at: ${WORK_DIR}/.env             │"
    warn "│                                                     │"
    warn "│  ⚠  You MUST edit it before starting the bot!       │"
    warn "│                                                     │"
    warn "│  Run:  nano ${WORK_DIR}/.env                        │"
    warn "└─────────────────────────────────────────────────────┘"
    echo ""
else
    success ".env already exists — keeping your existing config"
fi

# ═══════════════════════════════════════════════════════════════════
banner "Step 6/6 — Building Docker image"
# ═══════════════════════════════════════════════════════════════════

# -- Add swap if needed --
info "Checking swap..."
if [[ $(swapon --show | wc -l) -le 1 ]]; then
    info "No swap found. Creating 1GB swap file for Docker build..."
    info "  → dd if=/dev/zero of=/swapfile bs=1M count=1024"
    dd if=/dev/zero of=/swapfile bs=1M count=1024 status=progress || true
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo ""
    success "1GB swap enabled"
    free -h
    echo ""
else
    success "Swap already active"
    free -h
    echo ""
fi

# -- Stop old container if running --
info "Cleaning up old containers..."
docker stop aniwatchtv 2>/dev/null && info "  Stopped old container" || true
docker rm aniwatchtv 2>/dev/null && info "  Removed old container" || true
echo ""

# -- Build --
export DOCKER_BUILDKIT=1
info "Starting Docker build (this will take 10-20 min on ARM64)..."
info "You WILL see full build progress below ↓"
echo ""
echo -e "${YELLOW}────────────────── DOCKER BUILD START ──────────────────${NC}"
echo ""

docker build --progress=plain -t aniwatchtv:latest "${WORK_DIR}" 2>&1

echo ""
echo -e "${GREEN}────────────────── DOCKER BUILD DONE ───────────────────${NC}"
echo ""
success "Docker image built successfully!"
info "Image size: $(docker images aniwatchtv:latest --format '{{.Size}}')"

# ═══════════════════════════════════════════════════════════════════
banner "✅ Setup Complete!"
# ═══════════════════════════════════════════════════════════════════

# Check if .env is configured
if grep -q "^API_ID=$" "${WORK_DIR}/.env" 2>/dev/null; then
    echo ""
    echo -e "${YELLOW}${BOLD}  ⚠  .env is NOT configured yet!${NC}"
    echo ""
    echo -e "  ${BOLD}Next steps:${NC}"
    echo ""
    echo -e "  ${CYAN}1.${NC} Edit your credentials:"
    echo -e "     ${BOLD}nano /opt/AniwatchTvdl/.env${NC}"
    echo ""
    echo -e "  ${CYAN}2.${NC} Start the bot:"
    echo -e "     ${BOLD}docker run -d --name aniwatchtv \\${NC}"
    echo -e "     ${BOLD}  --env-file /opt/AniwatchTvdl/.env \\${NC}"
    echo -e "     ${BOLD}  --restart unless-stopped \\${NC}"
    echo -e "     ${BOLD}  --memory=768m \\${NC}"
    echo -e "     ${BOLD}  aniwatchtv:latest${NC}"
    echo ""
else
    info "Starting the bot..."
    docker run -d \
        --name aniwatchtv \
        --env-file "${WORK_DIR}/.env" \
        --restart unless-stopped \
        --memory=768m \
        aniwatchtv:latest

    echo ""
    success "Bot is RUNNING!"
    echo ""
    echo -e "  ${CYAN}Check logs:${NC}   docker logs -f aniwatchtv"
    echo -e "  ${CYAN}Restart:${NC}      docker restart aniwatchtv"
    echo -e "  ${CYAN}Stop:${NC}         docker stop aniwatchtv"
fi

echo ""
echo -e "  ${CYAN}Free disk:${NC}    docker system prune -af"
echo ""
