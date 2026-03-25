# ════════════════════════════════════════════════════════════
# FinansAsistan - Backend Dockerfile
# ════════════════════════════════════════════════════════════
FROM node:18-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy source
COPY . .

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

USER nodejs

EXPOSE 3001

CMD ["node", "back.js"]
