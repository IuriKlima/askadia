FROM node:22-bookworm-slim AS build
WORKDIR /app
RUN corepack enable && corepack prepare pnpm@10.33.0 --activate
COPY . .
RUN pnpm install --frozen-lockfile && pnpm build
RUN chown -R node:node /app/apps/web/.next
ENV NODE_ENV=production
ENV PORT=3000
ENV API_PORT=4000
ENV API_INTERNAL_URL=http://127.0.0.1:4000
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 CMD node -e "Promise.all([fetch('http://127.0.0.1:4000/health'),fetch('http://127.0.0.1:3000/login')]).then(r=>process.exit(r.every(x=>x.ok)?0:1)).catch(()=>process.exit(1))"
CMD ["node","scripts/start-production.mjs"]
