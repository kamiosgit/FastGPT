# Install dependencies only when needed 构建
FROM node:current-alpine AS deps
WORKDIR /app

# Install a specific version of pnpm
RUN npm install -g pnpm

# Copy package files
COPY package.json .
COPY pnpm-lock.yaml* ./

# Install dependencies and cache them
RUN pnpm install --frozen-lockfile

# Rebuild the source code only when needed
FROM node:current-alpine AS builder
WORKDIR /app

# Copy dependencies from deps stage
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/package.json ./package.json
COPY --from=deps /app/pnpm-lock.yaml* ./

# Copy project files
COPY . .

# Install the same version of pnpm globally
RUN npm install -g pnpm

# Build the project
RUN pnpm install --frozen-lockfile && pnpm run build

# Production image, copy all the files and run next
FROM node:current-alpine AS runner
WORKDIR /app

ENV NODE_ENV production
# Uncomment the following line in case you want to disable telemetry during runtime.
ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

RUN sed -i 's/https/http/' /etc/apk/repositories
RUN apk add --no-cache curl ca-certificates && update-ca-certificates

# Copy necessary files from builder stage
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

ENV PORT=3000
EXPOSE 3000

CMD ["node", "server.js"]
