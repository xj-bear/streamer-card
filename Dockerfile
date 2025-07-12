FROM node:20-alpine

LABEL authors="xj-bear"

# 安装 Chromium 和中文字体支持
RUN apk update && apk add --no-cache \
    chromium \
    nss \
    freetype \
    freetype-dev \
    harfbuzz \
    ca-certificates \
    ttf-freefont \
    wqy-zenhei

# 设置 Puppeteer 使用系统安装的 Chromium
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

WORKDIR /app

# 复制 package.json 和 package-lock.json (如果存在)
COPY package*.json ./

# 安装依赖
RUN npm install

# 复制源代码
COPY . .

# 编译 TypeScript
RUN npm run build

EXPOSE 3003

# 创建非 root 用户运行应用
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# 更改文件所有权
RUN chown -R nodejs:nodejs /app
USER nodejs

CMD [ "node", "dist/index.js" ]
