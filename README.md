<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=0:0d1117,50:161b22,100:1f6feb&height=220&section=header&text=AniwatchTvdl%20Docker&fontSize=50&fontColor=58a6ff&animation=fadeIn&fontAlignY=35&desc=ARM64%20One-Command%20Deployment&descSize=18&descAlignY=55&descColor=8b949e" width="100%" />
</p>

<h1 align="center">🐳 AniwatchTvdl — Docker Setup for ARM64</h1>

<p align="center">
  <b>One-command Docker build & deploy for the
  <a href="https://github.com/abhinai2244/AniwatchTvdl">AniwatchTvdl (Cantarella)</a>
  Telegram Anime Downloader Bot</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Amazon%20Linux%202023-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white" alt="Amazon Linux 2023" />
  <img src="https://img.shields.io/badge/Arch-ARM64%20(Graviton)-00979D?style=for-the-badge&logo=arm&logoColor=white" alt="ARM64" />
  <img src="https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker" />
  <img src="https://img.shields.io/badge/Python-3.11-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python 3.11" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/RAM-1GB%20Optimized-success?style=flat-square" />
  <img src="https://img.shields.io/badge/Disk-10GB%20SSD-success?style=flat-square" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" />
</p>

---

## 📋 Overview

This repository provides an **ARM64-optimized Docker setup** to deploy the [AniwatchTvdl (Cantarella)](https://github.com/abhinai2244/AniwatchTvdl) Telegram bot on resource-constrained ARM64 servers like **AWS Graviton** instances.

### Why is this needed?

The original repository has **3 critical issues** for ARM64 deployment:

| ❌ Problem | ✅ Our Fix |
|-----------|-----------|
| Dockerfile is incomplete (truncated mid-line) | Full multi-stage Dockerfile |
| Ships x86_64-only `N_m3u8DL-RE` binary | Compiles from source for ARM64 |
| No `WORKDIR`, `COPY`, `pip install`, or `CMD` | Complete build instructions |

---

## 🚀 Quick Start

### One Command — Does Everything

SSH into your **Amazon Linux 2023 ARM64** server and run:

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/Alaxroy121/solid-system/main/setup.sh)"
```

**Or clone & run manually:**

```bash
git clone https://github.com/Alaxroy121/solid-system.git
cd solid-system
sudo bash setup.sh
```

### What the script does automatically:

```
Step 1/6 → Installs git, curl, tar (bare AL2023 doesn't have these)
Step 2/6 → Installs & starts Docker
Step 3/6 → Clones the AniwatchTvdl source code
Step 4/6 → Writes the fixed ARM64 Dockerfile
Step 5/6 → Creates .env template for Telegram credentials
Step 6/6 → Adds swap + Builds & runs the Docker container
```

---

## ⚙️ Configuration

After the build completes, edit the `.env` file with your credentials:

```bash
nano /opt/AniwatchTvdl/.env
```

### Required Environment Variables

| Variable | Description | Where to Get |
|----------|-------------|--------------|
| `API_ID` | Telegram API ID | [my.telegram.org](https://my.telegram.org) |
| `API_HASH` | Telegram API Hash | [my.telegram.org](https://my.telegram.org) |
| `BOT_TOKEN` | Bot token | [@BotFather](https://t.me/BotFather) |
| `OWNER_ID` | Your Telegram user ID | [@userinfobot](https://t.me/userinfobot) |
| `MONGO_URL` | MongoDB connection string | [MongoDB Atlas](https://www.mongodb.com/atlas) (free) |
| `BOT_USERNAME` | Bot username (without @) | Your bot's username |
| `LOG_CHANNEL` | Channel ID for logs | Create a Telegram channel |
| `MAIN_CHANNEL` | Main channel ID | Your main channel |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SET_INTERVAL` | `60` | Airing check interval (seconds) |
| `TARGET_CHAT_ID` | — | Target chat for auto-uploads |
| `MONGO_NAME` | `cantarellabots` | Database name |
| `ADMIN_URL` | `@V_Sbotmaker` | Admin contact URL |
| `FSUB_PIC` | — | Force subscribe image URL |

Then start the bot:

```bash
docker run -d \
  --name aniwatchtv \
  --env-file /opt/AniwatchTvdl/.env \
  --restart unless-stopped \
  --memory=768m \
  aniwatchtv:latest
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│              Docker Multi-Stage Build            │
├─────────────────────────────────────────────────┤
│                                                  │
│  Stage 1: .NET SDK (Build)                       │
│  ├── Clones N_m3u8DL-RE source                   │
│  └── Compiles for linux-arm64                    │
│                                                  │
│  Stage 2: Python 3.11-slim (Runtime)             │
│  ├── Copies ARM64 N_m3u8DL-RE binary             │
│  ├── Installs ffmpeg + libicu                    │
│  ├── pip installs Python requirements            │
│  └── Runs: python3 -m cantarella                 │
│                                                  │
└─────────────────────────────────────────────────┘
```

---

## 🛠 Management Commands

```bash
# 📋 View live bot logs
docker logs -f aniwatchtv

# 🔄 Restart the bot
docker restart aniwatchtv

# ⏹️ Stop the bot
docker stop aniwatchtv

# ▶️ Start a stopped bot
docker start aniwatchtv

# 🔨 Rebuild after updates
cd /opt/AniwatchTvdl && \
docker build -t aniwatchtv:latest . && \
docker stop aniwatchtv && docker rm aniwatchtv && \
docker run -d --name aniwatchtv --env-file .env \
  --restart unless-stopped --memory=768m aniwatchtv:latest

# 🧹 Free disk space (important for 10GB SSD!)
docker system prune -af
docker builder prune -af
```

---

## 📁 Repository Structure

```
solid-system/
├── Dockerfile        # ARM64 multi-stage Docker build
├── setup.sh          # One-command installer script
├── README.md         # This file
└── LICENSE           # MIT License
```

---

## ⚠️ Resource Notes

> **💡 Build Time:** The first build takes **10–20 minutes** on ARM64 because it compiles N_m3u8DL-RE from .NET source. Subsequent builds use Docker cache and are much faster.

> **💡 Memory:** The script automatically creates **1GB swap** to prevent OOM during build. The running bot container uses only **~150–300MB RAM**.

> **💡 Disk:** After building, run `docker builder prune -af` to reclaim **~2–3GB** of build cache. The final image is ~500MB.

---

## 🙏 Credits

- **[AniwatchTvdl / Cantarella](https://github.com/abhinai2244/AniwatchTvdl)** — Original bot by [@abhinai2244](https://github.com/abhinai2244)
- **[N_m3u8DL-RE](https://github.com/nilaoda/N_m3u8DL-RE)** — HLS/DASH downloader by [@nilaoda](https://github.com/nilaoda)

---

<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=0:0d1117,50:161b22,100:1f6feb&height=100&section=footer" width="100%" />
</p>