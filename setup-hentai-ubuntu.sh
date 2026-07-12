#!/usr/bin/env bash
# ==============================================================================
#  Hentai DL Bot — Ubuntu x86_64 Automated Setup (Docker Compose)
# ==============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}    Hentai DL Bot — Ubuntu x86 Docker Compose Setup   ${NC}"
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
WORK_DIR="/opt/hentai_dl_bot"

if [[ -d "${WORK_DIR}" ]]; then
    echo "Directory ${WORK_DIR} already exists — pulling latest changes..."
    cd "${WORK_DIR}"
    git stash || true
    git pull origin master || true
else
    git clone https://github.com/VEncod/hentai_dl_bot.git "${WORK_DIR}"
    cd "${WORK_DIR}"
fi

# Create .env template if not exists
if [[ ! -f ".env" ]]; then
    cat > .env << 'ENV_EOF'
API_ID=
API_HASH=
BOT_TOKEN=
MONGO_URL=
OWNER_ID=
AUTH_USERS=
ENV_EOF
    echo -e "${GREEN}[INFO] Created template .env file. Edit it before starting the bot!${NC}"
fi

# Overwrite Dockerfile with x86_64 optimized version
echo -e "\n${YELLOW}Creating x86_64-optimized Dockerfile...${NC}"
cat > Dockerfile << 'DOCKERFILE_EOF'
FROM python:3.11-slim

# Install system dependencies + ICU libraries (required by N_m3u8DL-RE .NET runtime)
RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg \
        wget \
        curl \
        nodejs \
        npm \
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

WORKDIR /app
COPY requirements.txt .

RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt

COPY . .

# Make the bundled N_m3u8DL-RE binary executable (already x86 in repo)
RUN chmod +x binary/N_m3u8DL-RE || true

CMD ["python3", "app.py"]
DOCKERFILE_EOF

# Create docker-compose.yml
echo -e "${YELLOW}Creating docker-compose.yml...${NC}"
cat > docker-compose.yml << 'COMPOSE_EOF'
services:
  bot:
    build: .
    container_name: hentai_dl_bot
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
echo -e "     ${YELLOW}sudo nano /opt/hentai_dl_bot/.env${NC}"
echo ""
echo -e "  2. Start the bot:"
echo -e "     ${YELLOW}cd /opt/hentai_dl_bot && sudo docker compose up -d${NC}"
echo ""
echo -e "${BOLD}Useful Commands:${NC}"
echo -e "  ${YELLOW}sudo docker compose logs -f${NC}          — View live logs"
echo -e "  ${YELLOW}sudo docker compose restart${NC}           — Restart the bot"
echo -e "  ${YELLOW}sudo docker compose down${NC}              — Stop everything"
echo -e "  ${YELLOW}sudo docker compose up -d --build${NC}     — Rebuild & restart (after code update)"
echo ""
echo -e "${BOLD}To update the bot code later:${NC}"
echo -e "  ${YELLOW}cd /opt/hentai_dl_bot && sudo git pull && sudo docker compose up -d --build${NC}"
