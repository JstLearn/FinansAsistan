# ════════════════════════════════════════════════════════════
# FinansAsistan - Event Processor Dockerfile
# ════════════════════════════════════════════════════════════

FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY services/event-processor/package*.json ./

# Install dependencies
RUN npm install --only=production

# Copy source code
COPY services/event-processor/src/ ./src/

# Copy shared utilities from back directory (relative to project root)
COPY back/utils/logger.js ./back-utils/logger.js
COPY back/services/kafka/topics.js ./back-utils/topics.js
COPY back/utils/emailTemplates.js ./back-utils/emailTemplates.js

# Non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 3001

CMD ["node", "src/index.js"]

