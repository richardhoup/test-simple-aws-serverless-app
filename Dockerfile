FROM node:18-alpine AS base

# Install dependencies only when needed
FROM base AS deps
WORKDIR /app

# Copy package files
COPY package.json package-lock.json ./

# Install dependencies with aggressive cleanup
RUN npm ci --legacy-peer-deps && \
    npm cache clean --force && \
    rm -rf ~/.npm

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build the Next.js application
RUN npm run build

# Production image - use minimal approach
FROM node:18-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production

# Create a non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Install only production dependencies fresh (avoiding problematic flags)
COPY package.json package-lock.json ./
RUN npm install --production --legacy-peer-deps && \
    npm cache clean --force && \
    rm -rf ~/.npm

# Copy built application
COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

USER nextjs

# Expose port
EXPOSE 3000

# Run the application
CMD ["npm", "start"] 