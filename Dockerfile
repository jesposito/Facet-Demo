FROM golang:1.24-bookworm AS backend-builder

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libmupdf-dev \
    && rm -rf /var/lib/apt/lists/*

COPY upstream/backend/go.mod upstream/backend/go.sum ./
RUN go mod download

COPY upstream/backend/ ./
COPY scripts/apply-demo-transforms.sh /tmp/
RUN chmod +x /tmp/apply-demo-transforms.sh && /tmp/apply-demo-transforms.sh /build

RUN CGO_ENABLED=1 GOOS=linux go build -ldflags="-s -w" -o /facet .


FROM node:20-alpine AS frontend-builder

WORKDIR /build

COPY upstream/frontend/package*.json ./
RUN npm ci

COPY upstream/frontend/ ./
COPY overlay/frontend/ ./
COPY scripts/apply-frontend-transforms.sh /tmp/
RUN chmod +x /tmp/apply-frontend-transforms.sh && /tmp/apply-frontend-transforms.sh /build
ENV NODE_ENV=production
RUN npm run build


FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    tzdata \
    curl \
    caddy \
    pandoc \
    texlive-latex-base \
    texlive-latex-extra \
    texlive-xetex \
    texlive-fonts-recommended \
    lmodern \
    wget \
    openssl \
    gosu \
    cron \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -g 1000 facet \
    && useradd -u 1000 -g facet -s /bin/bash -m facet

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /app /data /uploads \
    && chown -R facet:facet /app /data /uploads

WORKDIR /app

COPY --from=backend-builder /facet ./facet
COPY --from=backend-builder /build/seeds/demo_assets ./backend/seeds/demo_assets
COPY --from=frontend-builder /build/build ./frontend/build
COPY --from=frontend-builder /build/package.json ./frontend/
COPY --from=frontend-builder /build/node_modules ./frontend/node_modules
COPY upstream/docker/Caddyfile ./Caddyfile
COPY overlay/docker/start.sh ./start.sh
COPY overlay/docker/reset-demo.sh ./reset-demo.sh

RUN chmod +x ./start.sh ./facet ./reset-demo.sh

ENV NODE_ENV=production
ENV POCKETBASE_URL=http://localhost:8090
ENV ADMIN_EMAILS=demo@example.com
ENV DEMO_MODE=true
ENV PORT=3000
ENV HOST=0.0.0.0

EXPOSE 8080

VOLUME ["/data", "/uploads"]

CMD ["./start.sh"]
