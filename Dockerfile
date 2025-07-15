FROM node:20-alpine3.19

LABEL authors="xj-bear"

# 安装 Chromium 和中文字体支持，以及Docker环境必要的依赖
RUN apk update && apk add --no-cache \
    chromium \
    nss \
    freetype \
    freetype-dev \
    harfbuzz \
    ca-certificates \
    ttf-freefont \
    wqy-zenhei \
    dbus \
    xvfb \
    xvfb-run \
    font-noto-cjk \
    font-noto-emoji \
    udev \
    wget \
    procps \
    && rm -rf /var/cache/apk/*

# 创建必要的目录和配置
RUN mkdir -p /run/dbus \
    && mkdir -p /tmp/.X11-unix \
    && chmod 1777 /tmp/.X11-unix

# 设置 Puppeteer 使用系统安装的 Chromium
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV DISPLAY=:99
ENV PUPPETEER_TIMEOUT=120000
ENV CHROME_BIN=/usr/bin/chromium-browser
ENV CHROME_PATH=/usr/bin/chromium-browser
# 抑制X11键盘警告
ENV XKB_DEFAULT_RULES=base
ENV XKB_DEFAULT_MODEL=pc105
ENV XKB_DEFAULT_LAYOUT=us
ENV XKB_DEFAULT_VARIANT=""
ENV XKB_DEFAULT_OPTIONS=""

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

# 创建启动脚本
RUN echo '#!/bin/sh' > /app/start.sh && \
    echo 'set -e' >> /app/start.sh && \
    echo '' >> /app/start.sh && \
    echo '# 清理可能存在的显示锁文件' >> /app/start.sh && \
    echo 'rm -f /tmp/.X99-lock' >> /app/start.sh && \
    echo '' >> /app/start.sh && \
    echo '# 启动虚拟显示' >> /app/start.sh && \
    echo 'Xvfb :99 -screen 0 1024x768x24 -ac +extension GLX +render -noreset &> /dev/null &' >> /app/start.sh && \
    echo 'export DISPLAY=:99' >> /app/start.sh && \
    echo '' >> /app/start.sh && \
    echo '# 等待显示启动' >> /app/start.sh && \
    echo 'sleep 3' >> /app/start.sh && \
    echo '' >> /app/start.sh && \
    echo '# 启动应用' >> /app/start.sh && \
    echo 'exec node dist/index.js' >> /app/start.sh && \
    chmod +x /app/start.sh

USER nodejs

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3003/api || exit 1

CMD ["/app/start.sh"]
