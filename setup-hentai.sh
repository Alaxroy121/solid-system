#!/usr/bin/env bash
# ==============================================================================
#  Hentai DL Bot — EC2 Amazon Linux 2023 (ARM64) Automated Setup
# ==============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}    Starting Automated Setup for Hentai DL Bot        ${NC}"
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
dnf install -y --allowerasing git tar curl gzip gcc python3-devel nano
dnf update -y

# ==============================================================================
# 2. Swap Memory Setup (Crucial for 1GB RAM instances)
# ==============================================================================
echo -e "\n${YELLOW}Step 2/5 — Configuring Swap Memory...${NC}"
if free | awk '/^Swap:/ {exit !$2}'; then
    echo -e "${GREEN}[OK] Swap is already active.${NC}"
else
    echo "Creating 1GB swap file..."
    fallocate -l 1G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=1024
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
    echo -e "${GREEN}[OK] Swap memory configured!${NC}"
fi

# ==============================================================================
# 3. Docker Installation
# ==============================================================================
echo -e "\n${YELLOW}Step 3/5 — Installing Docker...${NC}"
if ! command -v docker &> /dev/null; then
    dnf install -y docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user
    echo -e "${GREEN}[OK] Docker installed and started!${NC}"
else
    echo -e "${GREEN}[OK] Docker is already installed.${NC}"
    systemctl start docker || true
fi

# ==============================================================================
# 4. Clone Repository & Setup ARM64 Environment
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

# Create dummy .env if not exists
if [[ ! -f ".env" ]]; then
    cat > .env << 'ENV_EOF'
API_ID=
API_HASH=
BOT_TOKEN=
MONGO_URL=
OWNER_ID=
AUTH_USERS=
ENV_EOF
    echo -e "${GREEN}[INFO] Created template .env file.${NC}"
fi

# Overwrite Dockerfile with ARM64 Optimized version
echo -e "\n${YELLOW}Creating ARM64-optimized Dockerfile...${NC}"
cat > Dockerfile << 'DOCKERFILE_EOF'
FROM --platform=linux/arm64 python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg \
        wget \
        nodejs \
        npm \
        libicu72 \
        ca-certificates \
        gcc \
        g++ \
        make \
        python3-dev \
        libffi-dev \
        libssl-dev \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

WORKDIR /app
COPY requirements.txt .

RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt

# Download official linux-arm64 binary of N_m3u8DL-RE to replace the x86 one
RUN wget -q https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v0.2.1-beta/N_m3u8DL-RE_Beta_linux-arm64_20240828.tar.gz \
    && tar -xzf N_m3u8DL-RE_Beta_linux-arm64_20240828.tar.gz \
    && mv N_m3u8DL-RE_Beta_linux-arm64/N_m3u8DL-RE /usr/local/bin/ \
    && chmod +x /usr/local/bin/N_m3u8DL-RE \
    && rm -rf N_m3u8DL-RE_Beta_linux-arm64*

COPY . .

# Ensure the app uses the arm64 binary
RUN mkdir -p /app/binary && \
    ln -sf /usr/local/bin/N_m3u8DL-RE /app/binary/N_m3u8DL-RE

CMD ["python3", "app.py"]
DOCKERFILE_EOF

# ==============================================================================
# 5. Build Docker Image
# ==============================================================================
echo -e "\n${YELLOW}Step 5/5 — Building Docker Image (This will take a few minutes)...${NC}"
docker build --no-cache --progress=plain -t hentai-bot:latest .

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}    SETUP COMPLETE! 🎉                                ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "To start your bot, first edit your environment variables:"
echo -e "  ${YELLOW}sudo nano /opt/hentai_dl_bot/.env${NC}"
echo -e "\nThen run the bot using this command:"
echo -e "  ${YELLOW}sudo docker run -d --name hentai_dl_bot --env-file /opt/hentai_dl_bot/.env --restart unless-stopped --memory=768m hentai-bot:latest${NC}"
echo -e "\nTo check logs: ${YELLOW}sudo docker logs hentai_dl_bot${NC}"
