#!/bin/bash

echo "🚀 启动流光卡片 API 服务..."

# 检查端口是否被占用
if lsof -Pi :3003 -sTCP:LISTEN -t >/dev/null ; then
    echo "⚠️  端口 3003 已被占用，正在停止现有服务..."
    pkill -f "ts-node src/index.ts"
    sleep 2
fi

# 启动服务
echo "🔧 正在启动服务..."
npx ts-node src/index.ts &

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 5

# 检查服务状态
if curl -s http://localhost:3003/api >/dev/null; then
    echo "✅ 服务启动成功！"
    echo "🌐 API 地址: http://localhost:3003"
    echo "📋 可用端点:"
    echo "   - GET  /api                - 基础测试端点"
    echo "   - POST /api/saveImg        - 生成卡片"
    echo "   - POST /api/wxSaveImg      - 生成带广告的卡片"
    echo ""
    echo "💡 使用 ./test_api.sh 可以快速测试 API 功能"
    echo "🛑 使用 ./stop.sh 可以停止服务"
else
    echo "❌ 服务启动失败，请检查日志"
fi 