############################################
# Build Stage
############################################
FROM node:25-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    sqlite

# Copy package files
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=1
COPY .npmrc package.json package-lock.json ./

# Install ALL dependencies (including devDependencies for build)
RUN npm ci

# Copy application files
COPY . .

# Build frontend (creates dist/ directory) and clean up build cache
RUN npm run build && \
    npm cache clean --force && \
    rm -rf /root/.npm /tmp/*

# Remove devDependencies to reduce image size
RUN npm ci --omit=dev


############################################
# Runtime Stage
############################################
FROM node:25-alpine

WORKDIR /app

# Install runtime dependencies
# sqlite = database access
# curl = health checks and debugging
# iputils = for ping monitor type
# dumb-init = proper signal handling and zombie process reaping
# apprise = notification framework for 90+ services
RUN apk add --no-cache \
    sqlite \
    curl \
    iputils \
    dumb-init \
    tzdata \
    su-exec \
    ca-certificates \
    apprise --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community

# Create uptime-kuma user with UID/GID 3001
RUN addgroup -g 3001 uptime-kuma && \
    adduser -D -u 3001 -G uptime-kuma uptime-kuma

# Copy built files from builder stage
COPY --from=builder --chown=uptime-kuma:uptime-kuma /app/dist /app/dist
COPY --from=builder --chown=uptime-kuma:uptime-kuma /app/src /app/src
COPY --from=builder --chown=uptime-kuma:uptime-kuma /app/node_modules /app/node_modules
COPY --from=builder --chown=uptime-kuma:uptime-kuma /app/server /app/server
COPY --from=builder --chown=uptime-kuma:uptime-kuma /app/db /app/db
COPY --from=builder --chown=uptime-kuma:uptime-kuma /app/extra /app/extra
COPY --from=builder --chown=uptime-kuma:uptime-kuma /app/package.json /app/package.json
COPY --from=builder --chown=uptime-kuma:uptime-kuma /app/.npmrc /app/.npmrc

# Create the /app/data directory in the runtime image (needed for Docker copy-up)
RUN mkdir -p /app/data && chown -R 3001:3001 /app/data

# Environment variables
ENV NODE_ENV=production \
    UPTIME_KUMA_IS_CONTAINER=1

# Expose port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=60s --timeout=30s --start-period=180s --retries=5 \
    CMD node extra/healthcheck

# Start the application
USER root
ENTRYPOINT ["/usr/bin/dumb-init", "--", "sh", "-c", "chown -R 3001:3001 /app/data && chmod -R 755 /app/data && exec su-exec 3001:3001 node server/server.js"]