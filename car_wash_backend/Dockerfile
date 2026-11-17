# ---- Etapa 1: dependencias de producción (cacheable, sin devDependencies) ----
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# ---- Etapa 2: imagen final mínima ----
FROM node:20-alpine
ENV NODE_ENV=production
WORKDIR /app

# Procesos como PID 1 sin init no propagan SIGTERM bien; tini lo resuelve.
RUN apk add --no-cache tini

COPY --from=deps --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node . .
RUN mkdir -p logs && chown node:node logs

EXPOSE 5000
USER node

# /health responde 503 si MongoDB no está disponible.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${PORT:-5000}/health" >/dev/null || exit 1

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "server.js"]
