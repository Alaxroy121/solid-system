<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=0:0d1117,50:161b22,100:1f6feb&height=220&section=header&text=Telegram%20Anime%20Bots%20Docker&fontSize=40&fontColor=58a6ff&animation=fadeIn&fontAlignY=35&desc=ARM64%20One-Command%20Deployments&descSize=18&descAlignY=55&descColor=8b949e" width="100%" />
</p>

<h1 align="center">🐳 Telegram Anime Bots — Docker Setup for ARM64</h1>

<p align="center">
  <b>One-command Docker build & deploy scripts for popular Telegram Downloader Bots optimized for ARM64 (Graviton) servers.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Amazon%20Linux%202023-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white" alt="Amazon Linux 2023" />
  <img src="https://img.shields.io/badge/Arch-ARM64%20(Graviton)-00979D?style=for-the-badge&logo=arm&logoColor=white" alt="ARM64" />
  <img src="https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker" />
</p>

---

## 📋 Overview

This repository provides **ARM64-optimized Docker setups** to deploy three popular Telegram bots on resource-constrained ARM64 servers like **AWS Graviton** instances (1GB - 2GB RAM).

### The ARM64 Problem
Most Telegram downloader bots ship with `x86_64` binaries of `N_m3u8DL-RE`, `ffmpeg`, and miss C++ compilers for `tgcrypto`. This causes them to instantly crash on ARM64 servers.

**Our Fix:** These scripts completely rebuild the Docker environments, inject the correct `linux-arm64` binaries, install missing compilers, and configure safe RAM memory limits (to run multiple bots on one server).

---

## 🚀 Quick Start (One-Command Deployments)

SSH into your **Amazon Linux 2023 ARM64** server and run the script for the bot you want to deploy:

### 1. AniwatchTvdl (Cantarella)
```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/Alaxroy121/solid-system/main/Aniwatchtvdl.sh)"
```

### 2. Hentai DL Bot
```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/Alaxroy121/solid-system/main/setup-hentai.sh)"
```

### 3. Animedekho Bot (Includes local MongoDB)
```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/Alaxroy121/solid-system/main/setup-animedekho.sh)"
```

---

## 🛠 Manual Dockerfile Fixes

If you do not want to use the automated scripts and prefer to manually edit your own `Dockerfile`s for ARM64 compatibility, you must apply the following two fixes:

### Fix 1: Missing Compilers + ICU Libraries
Add this `apt-get` block to install `ffmpeg`, the required C-compilers for `tgcrypto`, and **ICU libraries** (required by N_m3u8DL-RE's .NET runtime — without these, the downloader crashes):
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

### Fix 2: Broken x86 downloader binary
Replace the old `curl` or `wget` command that downloads `N_m3u8DL-RE` with this ARM64-specific curl command:
```dockerfile
RUN curl -L -o /tmp/N_m3u8DL-RE.tar.gz \
    "https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v0.5.1-beta/N_m3u8DL-RE_v0.5.1-beta_linux-arm64_20251029.tar.gz" && \
    tar -xzf /tmp/N_m3u8DL-RE.tar.gz -C /usr/local/bin/ && \
    rm /tmp/N_m3u8DL-RE.tar.gz && \
    chmod +x /usr/local/bin/N_m3u8DL-RE
```

---

## ⚠️ Resource Notes
> **💡 Fast Updates:** We use Docker layer caching. Re-running the scripts to update your bot code takes only 1-2 seconds.
> **💡 Memory:** Always run your bots with `--memory=768m` or limit them in `docker-compose.yml` so you can safely run 3 bots on a 2GB RAM server without crashing.
