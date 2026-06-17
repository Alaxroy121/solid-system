#!/usr/bin/env bash
# ==============================================================================
#  Animedekho Bot — EC2 Amazon Linux 2023 (ARM64) Automated Setup
# ==============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}    Starting Automated Setup for Animedekho Bot       ${NC}"
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
# 2. Swap Memory Setup (Crucial for 1GB/2GB RAM instances)
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
echo -e "\n${YELLOW}Step 3/5 — Installing Docker & Docker Compose...${NC}"
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

# Install docker-compose if missing
if ! docker compose version &> /dev/null; then
    echo "Installing Docker Compose plugin..."
    DOCKER_CONFIG=${DOCKER_CONFIG:-/usr/local/lib/docker}
    mkdir -p $DOCKER_CONFIG/cli-plugins
    curl -SL https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-aarch64 -o $DOCKER_CONFIG/cli-plugins/docker-compose
    chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
    ln -s $DOCKER_CONFIG/cli-plugins/docker-compose /usr/bin/docker-compose || true
fi

# ==============================================================================
# 4. Clone Repository & Setup ARM64 Environment
# ==============================================================================
echo -e "\n${YELLOW}Step 4/5 — Setting up Bot Repository...${NC}"
WORK_DIR="/opt/animedekho-bot"

if [[ -d "${WORK_DIR}" ]]; then
    echo "Directory ${WORK_DIR} already exists — pulling latest changes..."
    cd "${WORK_DIR}"
    git stash || true
    git pull origin main || true
else
    git clone https://github.com/jrodr254/animedekho-bot.git "${WORK_DIR}"
    cd "${WORK_DIR}"
fi

# Create dummy .env if not exists
if [[ ! -f ".env" ]]; then
    cat > .env << 'ENV_EOF'
BOT_TOKEN=
API_ID=
API_HASH=
OWNER_ID=
MAIN_CHANNEL=
LOG_CHANNEL=
MONGO_URI=mongodb://mongo:27017/animedekho
ENV_EOF
    echo -e "${GREEN}[INFO] Created template .env file with local MongoDB URI.${NC}"
fi

# Overwrite Dockerfile with ARM64 Optimized version
echo -e "\n${YELLOW}Creating ARM64-optimized Dockerfile...${NC}"
cat > Dockerfile << 'DOCKERFILE_EOF'
FROM --platform=linux/arm64 python:3.11-slim

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
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Download official linux-arm64 binary of N_m3u8DL-RE instead of the x64 one
RUN wget -q https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v0.5.1-beta/N_m3u8DL-RE_v0.5.1-beta_linux-arm64_20251029.tar.gz \
    && tar -xzf N_m3u8DL-RE_v0.5.1-beta_linux-arm64_20251029.tar.gz -C /usr/local/bin/ \
    && rm N_m3u8DL-RE_v0.5.1-beta_linux-arm64_20251029.tar.gz \
    && chmod +x /usr/local/bin/N_m3u8DL-RE

WORKDIR /app
COPY requirements.txt .

RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt

COPY . .
RUN mkdir -p /app/data

CMD ["python", "main.py"]
DOCKERFILE_EOF

# Overwrite docker-compose.yml to enforce memory limits
cat > docker-compose.yml << 'COMPOSE_EOF'
version: "3.8"

services:
  bot:
    build: .
    container_name: animedekho-bot
    restart: unless-stopped
    env_file: .env
    volumes:
      - bot-data:/app/data
      - bot-tmp:/tmp/animedekho_dl
    depends_on:
      - mongo
    deploy:
      resources:
        limits:
          memory: 768M

  mongo:
    image: mongo:7
    container_name: animedekho-mongo
    restart: unless-stopped
    volumes:
      - mongo-data:/data/db
    ports:
      - "27017:27017"
    deploy:
      resources:
        limits:
          memory: 512M

volumes:
  bot-data:
  bot-tmp:
  mongo-data:
COMPOSE_EOF

# ==============================================================================
# 5. Build and Deploy using Docker Compose
# ==============================================================================
echo -e "\n${YELLOW}Step 5/5 — Building and Starting (Docker Compose)...${NC}"
# Use standard docker build to utilize cache without compose cache bugs, then up
docker build --progress=plain -t animedekho:latest .
docker compose up -d

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}    SETUP COMPLETE! 🎉                                ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "To configure your bot, edit your environment variables:"
echo -e "  ${YELLOW}sudo nano /opt/animedekho-bot/.env${NC}"
echo -e "\nAfter editing, apply the changes by running:"
echo -e "  ${YELLOW}cd /opt/animedekho-bot && sudo docker compose up -d${NC}"
echo -e "\nTo check bot logs:  ${YELLOW}sudo docker logs -f animedekho-bot${NC}"
