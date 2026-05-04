FROM python:3.11-slim-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium \
    chromium-driver \
    cron \
    curl \
    ca-certificates \
    fonts-liberation \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libdbus-1-3 \
    libgbm1 \
    libgtk-3-0 \
    libnss3 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    xdg-utils \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY SyncOnelapToXoss.py incremental_sync_v2.py ./
COPY settings.ini.example ./settings.ini.example

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV CHROMIUM_PATH=/usr/bin/chromium
ENV DISPLAY=""

# Port for Strava OAuth callback (only needed for --strava-auth)
EXPOSE 8765

ENTRYPOINT ["/entrypoint.sh"]
