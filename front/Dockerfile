# ════════════════════════════════════════════════════════════
# FinansAsistan - Frontend Dockerfile (Production)
# Multi-stage build with nginx for static serving
# ════════════════════════════════════════════════════════════

# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Harden npm fetch against transient registry 5xx
ENV npm_config_fetch_retries=5 \
    npm_config_fetch_retry_mintimeout=20000 \
    npm_config_fetch_retry_maxtimeout=120000 \
    npm_config_registry=https://registry.npmjs.org/

# Build arguments to invalidate cache on every build
ARG BUILD_DATE
ARG GIT_COMMIT
ARG GIT_COMMIT_SHORT
# API base URL (injected at build time) - must be provided by build args/env
ARG REACT_APP_API_URL=""
# Use build args in a way that forces cache invalidation
LABEL build_date="${BUILD_DATE}" \
      git_commit="${GIT_COMMIT}" \
      git_commit_short="${GIT_COMMIT_SHORT}"

# Copy package files
COPY package*.json ./

# Install dependencies
# Use --legacy-peer-deps to handle React 19 / React Native peer dependency conflict
RUN npm ci --legacy-peer-deps

# Copy application code
COPY . .

# Build application
# Inject API URL into build env
ENV REACT_APP_API_URL=${REACT_APP_API_URL}
# Use build args in the build command to force cache invalidation
RUN echo "Building with commit: ${GIT_COMMIT_SHORT} at ${BUILD_DATE} / API=${REACT_APP_API_URL}" && \
    npm run build

# Production stage - nginx
FROM nginx:alpine

# Copy built files from builder
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration for SPA routing
# Override default.conf to ensure our config is used
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Verify files are copied correctly (debug)
RUN ls -la /usr/share/nginx/html/ && \
    ls -la /etc/nginx/conf.d/

# Expose port
EXPOSE 80

# Health check - use curl since wget has issues on Alpine
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -f http://localhost/health || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]

