#!/bin/bash

echo "=== 流光卡片 Docker 部署脚本 ==="
echo ""

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装，请先安装 Docker"
    exit 1
fi

# 检查 docker-compose 是否安装
if ! command -v docker-compose &> /dev/null; then
    echo "❌ docker-compose 未安装，请先安装 docker-compose"
    exit 1
fi

echo "✅ Docker 环境检查通过"
echo ""

# 停止现有容器
echo "🛑 停止现有容器..."
docker-compose down 2>/dev/null || true

# 清理旧镜像
echo "🧹 清理旧镜像..."
docker image prune -f

# 构建新镜像
echo "🔨 构建新镜像..."
docker-compose build --no-cache

# 启动服务
echo "🚀 启动服务..."
docker-compose up -d

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 10

# 检查服务状态
echo "🔍 检查服务状态..."
if curl -s http://localhost:3003/api > /dev/null; then
    echo "✅ 服务启动成功！"
    echo "📍 API 地址: http://localhost:3003"
    echo "📍 测试接口: http://localhost:3003/api"
    echo ""
    echo "📋 常用命令:"
    echo "  查看日志: docker-compose logs -f"
    echo "  停止服务: docker-compose down"
    echo "  重启服务: docker-compose restart"
else
    echo "❌ 服务启动失败，请检查日志:"
    echo "docker-compose logs"
fi

echo ""
echo "=== 部署完成 ==="
