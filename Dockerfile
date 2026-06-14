# ─────────────────────────────────────────────────────────────────
# AniwatchTvdl (Cantarella Bot) — ARM64-optimized Dockerfile
# ─────────────────────────────────────────────────────────────────

FROM --platform=linux/arm64 python:3.11-slim-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg \
        wget \
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

RUN wget -q https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v0.2.1-beta/N_m3u8DL-RE_Beta_linux-arm64_20240828.tar.gz \
    && tar -xzf N_m3u8DL-RE_Beta_linux-arm64_20240828.tar.gz \
    && mv N_m3u8DL-RE_Beta_linux-arm64/N_m3u8DL-RE /usr/local/bin/ \
    && chmod +x /usr/local/bin/N_m3u8DL-RE \
    && rm -rf N_m3u8DL-RE_Beta_linux-arm64*

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
