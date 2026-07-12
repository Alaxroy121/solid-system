<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=0:0d1117,50:161b22,100:1f6feb&height=220&section=header&text=Ubuntu%20x86%20Bot%20Deployments&fontSize=40&fontColor=58a6ff&animation=fadeIn&fontAlignY=35&desc=Docker%20Compose%20One-Command%20Setup&descSize=18&descAlignY=55&descColor=8b949e" width="100%" />
</p>

<h1 align="center">🐳 Telegram Anime Bots — Ubuntu x86_64 Docker Compose Setup</h1>

<p align="center">
  <b>One-command Docker Compose deployments for popular Telegram Downloader Bots on Ubuntu x86 servers.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/OS-Ubuntu%2020.04%20/%2022.04%20/%2024.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Ubuntu" />
  <img src="https://img.shields.io/badge/Arch-x86__64%20(Intel%20/%20AMD)-0071C5?style=for-the-badge&logo=intel&logoColor=white" alt="x86_64" />
  <img src="https://img.shields.io/badge/Docker%20Compose-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker Compose" />
  <img src="https://img.shields.io/badge/Python-3.11-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python 3.11" />
</p>

---

## 📋 Overview

These scripts automate the full deployment of three Telegram downloader bots on **Ubuntu x86_64** servers using **Docker Compose**.

Each script handles everything automatically:
- ✅ Installs Docker Engine + Docker Compose plugin (official repo)
- ✅ Smart Swap: auto-detects RAM — skips swap if ≥ 4GB, creates 2GB if < 2GB, creates 1GB if 2–4GB
- ✅ Clones the bot repository
- ✅ Writes an optimized Dockerfile with `libicu-dev` (ICU libraries for N_m3u8DL-RE)
- ✅ Creates `docker-compose.yml` with memory limits
- ✅ Builds the Docker image

> **Looking for ARM64 (AWS Graviton) scripts?** See the main [README.md](README.md).

---

## 🚀 Quick Start

SSH into your **Ubuntu x86_64** server and run the script for the bot you want:

### 1. AniwatchTvdl (Cantarella)

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/Alaxroy121/solid-system/main/setup-aniwatchtv-ubuntu.sh)"
```

After setup:
```bash
sudo nano /opt/AniwatchTvdl/.env          # Fill in your credentials
cd /opt/AniwatchTvdl && sudo docker compose up -d    # Start the bot
```

### 2. Hentai DL Bot

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/Alaxroy121/solid-system/main/setup-hentai-ubuntu.sh)"
```

After setup:
```bash
sudo nano /opt/hentai_dl_bot/.env          # Fill in your credentials
cd /opt/hentai_dl_bot && sudo docker compose up -d   # Start the bot
```

### 3. Animedekho Bot

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/Alaxroy121/solid-system/main/setup-animedekho-ubuntu.sh)"
```

After setup:
```bash
sudo nano /opt/animedekho-bot/.env         # Fill in your credentials
cd /opt/animedekho-bot && sudo docker compose up -d  # Start the bot
```

---

## ⚙️ Environment Variables

Each bot creates a `.env` template file. You **must** fill it in before starting.

### AniwatchTvdl

| Variable | Required | Description | Where to Get |
|----------|----------|-------------|--------------|
| `API_ID` | ✅ | Telegram API ID | [my.telegram.org](https://my.telegram.org) |
| `API_HASH` | ✅ | Telegram API Hash | [my.telegram.org](https://my.telegram.org) |
| `BOT_TOKEN` | ✅ | Bot token | [@BotFather](https://t.me/BotFather) |
| `OWNER_ID` | ✅ | Your Telegram user ID | [@userinfobot](https://t.me/userinfobot) |
| `MONGO_URL` | ✅ | MongoDB connection string | [MongoDB Atlas](https://www.mongodb.com/atlas) (free) |
| `BOT_USERNAME` | ✅ | Bot username (without @) | Your bot's username |
| `LOG_CHANNEL` | ❌ | Channel ID for logs | Create a Telegram channel |
| `MAIN_CHANNEL` | ❌ | Main channel ID | Your main channel |

### Hentai DL Bot

| Variable | Required | Description |
|----------|----------|-------------|
| `API_ID` | ✅ | Telegram API ID |
| `API_HASH` | ✅ | Telegram API Hash |
| `BOT_TOKEN` | ✅ | Bot token |
| `MONGO_URL` | ✅ | MongoDB connection string |
| `OWNER_ID` | ✅ | Your Telegram user ID |
| `AUTH_USERS` | ❌ | Comma-separated authorized user IDs |

### Animedekho Bot

| Variable | Required | Description |
|----------|----------|-------------|
| `API_ID` | ✅ | Telegram API ID |
| `API_HASH` | ✅ | Telegram API Hash |
| `BOT_TOKEN` | ✅ | Bot token |
| `OWNER_ID` | ✅ | Your Telegram user ID |
| `MONGO_URI` | ✅ | MongoDB connection string |
| `MAIN_CHANNEL` | ❌ | Channel ID for library posts |
| `LOG_CHANNEL` | ❌ | Channel ID for bot logs |

> ⚠️ **Important:** Do NOT put quotation marks `""` around numeric values like `API_ID` or `OWNER_ID` — this will crash the bot!

---

## 🛠 Docker Compose Management

All three bots use the same Docker Compose commands. Just `cd` into the bot's directory first.

```bash
# View live logs
sudo docker compose logs -f

# Restart the bot
sudo docker compose restart

# Stop the bot
sudo docker compose down

# Rebuild & restart (after code changes)
sudo docker compose up -d --build
```

---

## 🔄 Updating Bot Code

To pull the latest code from GitHub and rebuild:

```bash
cd /opt/<bot-directory>
sudo git pull
sudo docker compose up -d --build
```

Replace `<bot-directory>` with:
- `AniwatchTvdl` — for AniwatchTvdl
- `hentai_dl_bot` — for Hentai DL Bot
- `animedekho-bot` — for Animedekho Bot

---

## 🧠 Smart Swap Detection

The scripts automatically detect your server's RAM and decide whether swap is needed:

| Server RAM | Swap Created | Total Memory |
|------------|-------------|--------------|
| **≥ 4 GB** | ❌ None (not needed) | 4+ GB |
| **2–4 GB** | ✅ 1 GB | 3–5 GB |
| **< 2 GB** | ✅ 2 GB | 2–4 GB |

---

## 🖥️ Running Multiple Bots on One Server

You can safely run all 3 bots on the same server. Each bot's `docker-compose.yml` enforces a **768 MB memory limit** per container.

| Server RAM | Max Bots Recommended |
|------------|---------------------|
| 2 GB | 2 bots |
| 4 GB | 3 bots (comfortable) |
| 8 GB+ | 3 bots + room to spare |

---

## 🛠 Manual Dockerfile Fixes

If you prefer to manually fix your own Dockerfiles instead of using these scripts, apply these two changes:

### Fix 1: Missing Compilers + ICU Libraries
```dockerfile
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ffmpeg \
    curl \
    ca-certificates \
    gcc \
    g++ \
    make \
    python3-dev \
    libffi-dev \
    libssl-dev \
    libicu-dev \
    && rm -rf /var/lib/apt/lists/*
```

### Fix 2: N_m3u8DL-RE x64 Binary
```dockerfile
RUN curl -L -o /tmp/N_m3u8DL-RE.tar.gz \
    "https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v0.5.1-beta/N_m3u8DL-RE_v0.5.1-beta_linux-x64_20251029.tar.gz" && \
    tar -xzf /tmp/N_m3u8DL-RE.tar.gz -C /usr/local/bin/ && \
    rm /tmp/N_m3u8DL-RE.tar.gz && \
    chmod +x /usr/local/bin/N_m3u8DL-RE
```

---

## 📁 Repository Structure

```
solid-system/
├── README.md                       # ARM64 (Graviton) scripts documentation
├── README-ubuntu.md                # This file — Ubuntu x86 documentation
│
├── # ARM64 Scripts (Amazon Linux 2023)
├── Aniwatchtvdl.sh                 # AniwatchTvdl — ARM64
├── setup-hentai.sh                 # Hentai DL Bot — ARM64
├── setup-animedekho.sh             # Animedekho Bot — ARM64
│
├── # Ubuntu x86 Scripts (Docker Compose)
├── setup-aniwatchtv-ubuntu.sh      # AniwatchTvdl — Ubuntu x86
├── setup-hentai-ubuntu.sh          # Hentai DL Bot — Ubuntu x86
├── setup-animedekho-ubuntu.sh      # Animedekho Bot — Ubuntu x86
│
├── Dockerfile                      # Standalone ARM64 Dockerfile
└── LICENSE
```

---

<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=0:0d1117,50:161b22,100:1f6feb&height=100&section=footer" width="100%" />
</p>
