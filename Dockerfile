# ─────────────────────────────────────────────────────────────────
# AniwatchTvdl (Cantarella Bot) — ARM64-optimized Dockerfile
# Targets: Amazon Linux 2023 / ARM64 (Graviton) / 1GB RAM / 10GB SSD
# ─────────────────────────────────────────────────────────────────

# Stage 1: Build N_m3u8DL-RE from source for linux-arm64
# (The repo ships an x64 binary that won't run on ARM64)
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

# Install only what's needed at runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg \
        libicu72 \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy the ARM64 N_m3u8DL-RE binary from builder
COPY --from=m3u8build /out/N_m3u8DL-RE /usr/local/bin/N_m3u8DL-RE
RUN chmod +x /usr/local/bin/N_m3u8DL-RE

WORKDIR /app

# Install Python dependencies first (layer caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy full application source
COPY . .

# Also symlink the binary into binary/ for run.sh compatibility
RUN mkdir -p /app/binary && \
    ln -sf /usr/local/bin/N_m3u8DL-RE /app/binary/N_m3u8DL-RE

# The bot entry point
CMD ["python3", "-m", "cantarella"]
