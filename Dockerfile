ARG NVM_VERSION=v0.40.3
ARG NODE_VERSION=22.18.0
ARG BUN_VERSION=1.2

FROM oven/bun:${BUN_VERSION} AS build
WORKDIR /app
RUN apt-get update && apt-get install -y curl
ARG NVM_VERSION
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash
ENV NVM_DIR=/root/.nvm
ARG NODE_VERSION
RUN . "$NVM_DIR/nvm.sh" \
  && nvm install "${NODE_VERSION}" \
  && nvm use --delete-prefix "${NODE_VERSION}" \
  && nvm alias default "${NODE_VERSION}" \
  ;
ENV PATH="/root/.nvm/versions/node/v${NODE_VERSION}/bin:${PATH}"
ENV NODE_ENV=production
COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile
COPY . .
RUN bun run build --external electron

FROM node:${NODE_VERSION}-bookworm-slim
WORKDIR /app
ENV NODE_ENV=production
# Install PM2 (process manager)
RUN npm i -g pm2
RUN npx playwright install-deps \
  && npx playwright install firefox \
  ;
COPY --from=oven/bun:1 /usr/local/bin/bun /usr/local/bin/bun
COPY --from=build /app/dist/server ./
# Install dependencies for playwright
RUN npx playwright install-deps \
  && npx playwright install --force firefox \
  && npm i playwright-core \
  ;
# Install browsers for playwright
CMD ["./server"]
