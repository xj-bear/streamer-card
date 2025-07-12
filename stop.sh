#!/bin/bash

echo "🛑 停止流光卡片 API 服务..."

# 查找并停止进程
if pgrep -f "ts-node src/index.ts" > /dev/null; then
    echo "🔍 找到运行中的服务进程..."
    pkill -f "ts-node src/index.ts"
    sleep 2
    
    # 检查是否成功停止
    if ! pgrep -f "ts-node src/index.ts" > /dev/null; then
        echo "✅ 服务已成功停止"
    else
        echo "⚠️  强制停止服务..."
        pkill -9 -f "ts-node src/index.ts"
        echo "✅ 服务已强制停止"
    fi
else
    echo "ℹ️  未找到运行中的服务进程"
fi

# 检查端口是否释放
if ! lsof -Pi :3003 -sTCP:LISTEN -t >/dev/null ; then
    echo "🔓 端口 3003 已释放"
else
    echo "⚠️  端口 3003 仍被占用"
fi 