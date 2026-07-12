#!/usr/bin/env bash
# ==============================================================================
#  AniwatchTvdl (Cantarella) — Ubuntu x86_64 Automated Setup (Docker Compose)
# ==============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}    AniwatchTvdl — Ubuntu x86 Docker Compose Setup    ${NC}"
echo -e "${GREEN}======================================================${NC}"

# Check for root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERROR] Please run this script with sudo:${NC} sudo bash -c \"\$(curl -fsSL ...)\""
  exit 1
fi

# ==============================================================================
# 1. Update & Essential Tools
# ==============================================================================
echo -e "\n${YELLOW}Step 1/5 — Installing essential tools...${NC}"
apt-get update -y
apt-get install -y git curl wget nano ca-certificates gnupg lsb-release

# ==============================================================================
# 2. Smart Swap Memory Setup (Only if RAM < 4GB)
# ==============================================================================
echo -e "\n${YELLOW}Step 2/5 — Checking RAM & Configuring Swap...${NC}"

TOTAL_RAM_MB=$(free -m | awk '/^Mem:/ {print $2}')
echo -e "  Detected RAM: ${BOLD}${TOTAL_RAM_MB} MB${NC}"

if [ "$TOTAL_RAM_MB" -ge 4000 ]; then
    echo -e "  ${GREEN}[OK] RAM is 4GB or more — Swap is not needed.${NC}"
else
    echo -e "  ${YELLOW}[INFO] RAM is less than 4GB — Setting up Swap...${NC}"
    if free | awk '/^Swap:/ {exit !$2}'; then
        echo -e "  ${GREEN}[OK] Swap is already active.${NC}"
    else
        if [ "$TOTAL_RAM_MB" -lt 2000 ]; then
            SWAP_SIZE="2G"
        else
            SWAP_SIZE="1G"
        fi
        echo "  Creating ${SWAP_SIZE} swap file..."
        fallocate -l ${SWAP_SIZE} /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=$((${SWAP_SIZE%G} * 1024))
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        if ! grep -q '/swapfile' /etc/fstab; then
            echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
        fi
        echo -e "  ${GREEN}[OK] ${SWAP_SIZE} Swap memory configured!${NC}"
    fi
fi

# ==============================================================================
# 3. Docker & Docker Compose Installation
# ==============================================================================
echo -e "\n${YELLOW}Step 3/5 — Installing Docker & Docker Compose...${NC}"

if ! command -v docker &> /dev/null; then
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
        apt-get remove -y $pkg 2>/dev/null || true
    done

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null || true
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    systemctl enable docker
    systemctl start docker

    if [ -n "$SUDO_USER" ]; then
        usermod -aG docker "$SUDO_USER"
    fi

    echo -e "${GREEN}[OK] Docker + Docker Compose installed!${NC}"
else
    echo -e "${GREEN}[OK] Docker is already installed.${NC}"
    systemctl start docker || true

    if ! docker compose version &> /dev/null; then
        apt-get update -y
        apt-get install -y docker-compose-plugin
    fi
fi

echo -e "  Docker version: $(docker --version)"
echo -e "  Compose version: $(docker compose version)"

# ==============================================================================
# 4. Clone Repository & Setup x86 Environment
# ==============================================================================
echo -e "\n${YELLOW}Step 4/5 — Setting up Bot Repository...${NC}"
WORK_DIR="/opt/AniwatchTvdl"

if [[ -d "${WORK_DIR}" ]]; then
    echo "Directory ${WORK_DIR} already exists — pulling latest changes..."
    cd "${WORK_DIR}"
    git stash || true
    git pull origin main || true
else
    git clone https://github.com/abhinai2244/AniwatchTvdl.git "${WORK_DIR}"
    cd "${WORK_DIR}"
fi

# Create .env template if not exists
if [[ ! -f ".env" ]]; then
    cat > .env << 'ENV_EOF'
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
    echo -e "${GREEN}[INFO] Created template .env file. Edit it before starting the bot!${NC}"
fi

# Overwrite Dockerfile with x86_64 optimized version
echo -e "\n${YELLOW}Creating x86_64-optimized Dockerfile...${NC}"
cat > Dockerfile << 'DOCKERFILE_EOF'
FROM python:3.11-slim-bookworm

# Install system dependencies + ICU libraries (required by N_m3u8DL-RE .NET runtime)
RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg \
        wget \
        curl \
        ca-certificates \
        gcc \
        g++ \
        make \
        python3-dev \
        libffi-dev \
        libssl-dev \
        libicu-dev \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Download N_m3u8DL-RE (x64 binary)
RUN curl -L -o /tmp/N_m3u8DL-RE.tar.gz \
    "https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v0.2.1-beta/N_m3u8DL-RE_Beta_linux-x64_20240828.tar.gz" && \
    tar -xzf /tmp/N_m3u8DL-RE.tar.gz && \
    mv N_m3u8DL-RE_Beta_linux-x64/N_m3u8DL-RE /usr/local/bin/ && \
    chmod +x /usr/local/bin/N_m3u8DL-RE && \
    rm -rf N_m3u8DL-RE_Beta_linux-x64*

WORKDIR /app

COPY requirements.txt .
RUN sed -i '/curl_cffi/d' requirements.txt && \
    pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir curl_cffi --pre && \
    pip install --no-cache-dir -r requirements.txt

COPY . .

RUN mkdir -p /app/binary && \
    ln -sf /usr/local/bin/N_m3u8DL-RE /app/binary/N_m3u8DL-RE

CMD ["python3", "-m", "cantarella"]
DOCKERFILE_EOF

# Create docker-compose.yml
echo -e "${YELLOW}Creating docker-compose.yml...${NC}"
cat > docker-compose.yml << 'COMPOSE_EOF'
services:
  bot:
    build: .
    container_name: aniwatchtv
    restart: unless-stopped
    env_file: .env
    mem_limit: 768m

COMPOSE_EOF

# ==============================================================================
# 5. Build & Start with Docker Compose
# ==============================================================================
echo -e "\n${YELLOW}Step 5/5 — Building with Docker Compose...${NC}"
docker compose build --progress=plain

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}    SETUP COMPLETE! 🎉                                ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo ""
echo -e "${BOLD}Next Steps:${NC}"
echo ""
echo -e "  1. Edit your environment variables:"
echo -e "     ${YELLOW}sudo nano /opt/AniwatchTvdl/.env${NC}"
echo ""
echo -e "  2. Start the bot:"
echo -e "     ${YELLOW}cd /opt/AniwatchTvdl && sudo docker compose up -d${NC}"
echo ""
echo -e "${BOLD}Useful Commands:${NC}"
echo -e "  ${YELLOW}sudo docker compose logs -f${NC}          — View live logs"
echo -e "  ${YELLOW}sudo docker compose restart${NC}           — Restart the bot"
echo -e "  ${YELLOW}sudo docker compose down${NC}              — Stop everything"
echo -e "  ${YELLOW}sudo docker compose up -d --build${NC}     — Rebuild & restart (after code update)"
echo ""
echo -e "${BOLD}To update the bot code later:${NC}"
echo -e "  ${YELLOW}cd /opt/AniwatchTvdl && sudo git pull && sudo docker compose up -d --build${NC}"
