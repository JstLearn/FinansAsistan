# ════════════════════════════════════════════════════════════
# FinansAsistan - Frontend Dockerfile (Root)
# ════════════════════════════════════════════════════════════
FROM node:18-alpine
WORKDIR /app
COPY front/package*.json ./
RUN npm ci --only=production
COPY front/ .
RUN npm run build
EXPOSE 3000
CMD ["node", "front.js"]
