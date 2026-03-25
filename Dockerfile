# ════════════════════════════════════════════════════════════
# FinansAsistan - Root Dockerfile (Dev/Testing)
# ════════════════════════════════════════════════════════════
FROM node:18-alpine

WORKDIR /app

# Copy backend
COPY back/ ./back/

# Install backend dependencies
WORKDIR /app/back
RUN npm install --production

WORKDIR /app

EXPOSE 5000

CMD ["node", "back/back.js"]
