#!/bin/bash

# 流媒体卡片生成服务部署脚本
# 支持标准配置和低配置模式

set -e

echo "🚀 流媒体卡片生成服务部署脚本"
echo "================================"

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装，请先安装 Docker"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose 未安装，请先安装 Docker Compose"
    exit 1
fi

# 选择部署模式
echo ""
echo "请选择部署模式："
echo "1) 标准配置 (推荐用于2GB+内存的服务器)"
echo "2) 低配置模式 (适用于1GB内存的服务器)"
echo ""
read -p "请输入选择 (1 或 2): " choice

case $choice in
    1)
        COMPOSE_FILE="docker-compose.yml"
        MODE="标准配置"
        ;;
    2)
        COMPOSE_FILE="docker-compose.low-spec.yml"
        MODE="低配置"
        ;;
    *)
        echo "❌ 无效选择，退出部署"
        exit 1
        ;;
esac

echo ""
echo "📋 部署信息："
echo "   模式: $MODE"
echo "   配置文件: $COMPOSE_FILE"
echo "   端口: 9200"
echo ""

# 停止现有容器
echo "🛑 停止现有容器..."
docker-compose -f docker-compose.yml down 2>/dev/null || true
docker-compose -f docker-compose.low-spec.yml down 2>/dev/null || true

# 清理旧镜像
echo "🧹 清理旧镜像..."
docker image prune -f

# 构建并启动服务
echo "🔨 构建并启动服务..."
if command -v docker-compose &> /dev/null; then
    docker-compose -f $COMPOSE_FILE up -d --build
else
    docker compose -f $COMPOSE_FILE up -d --build
fi

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 30

# 检查服务状态
echo "🔍 检查服务状态..."
if command -v docker-compose &> /dev/null; then
    docker-compose -f $COMPOSE_FILE ps
else
    docker compose -f $COMPOSE_FILE ps
fi

# 健康检查
echo "🏥 执行健康检查..."
for i in {1..10}; do
    if curl -f http://localhost:9200/api >/dev/null 2>&1; then
        echo "✅ 服务健康检查通过！"
        break
    else
        echo "⏳ 等待服务启动... ($i/10)"
        sleep 10
    fi

    if [ $i -eq 10 ]; then
        echo "❌ 服务启动失败，请检查日志"
        if command -v docker-compose &> /dev/null; then
            docker-compose -f $COMPOSE_FILE logs --tail=20
        else
            docker compose -f $COMPOSE_FILE logs --tail=20
        fi
        exit 1
    fi
done

echo ""
echo "🎉 部署完成！"
echo "================================"
echo "📍 服务地址: http://localhost:9200"
echo "🔗 API端点: http://localhost:9200/api/saveImg"
echo "📊 健康检查: http://localhost:9200/api"
echo ""
echo "📝 使用说明："
echo "   - 发送POST请求到 /api/saveImg 生成图片"
echo "   - 请求体格式请参考 test_long_content.json"
echo ""
echo "🔧 管理命令："
if command -v docker-compose &> /dev/null; then
    echo "   查看日志: docker-compose -f $COMPOSE_FILE logs -f"
    echo "   停止服务: docker-compose -f $COMPOSE_FILE down"
    echo "   重启服务: docker-compose -f $COMPOSE_FILE restart"
else
    echo "   查看日志: docker compose -f $COMPOSE_FILE logs -f"
    echo "   停止服务: docker compose -f $COMPOSE_FILE down"
    echo "   重启服务: docker compose -f $COMPOSE_FILE restart"
fi
echo ""
