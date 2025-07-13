#!/bin/bash

echo "=== 服务器强制还原到指定版本脚本 ==="
echo ""

TARGET_COMMIT="14e1b0c31da4ef7a37b897d09848788c30cdcafd"

# 1. 停止所有服务
echo "🛑 停止所有服务..."
docker-compose down 2>/dev/null || true
docker-compose -f docker-compose.ultra-optimized.yml down 2>/dev/null || true
docker-compose -f docker-compose.low-spec.yml down 2>/dev/null || true
docker-compose -f docker-compose.prod.yml down 2>/dev/null || true

# 2. 清理Docker资源
echo "🧹 清理Docker资源..."
docker system prune -f

# 3. 强制还原到指定版本
echo "📥 强制还原到指定版本: $TARGET_COMMIT"
git fetch origin
git reset --hard $TARGET_COMMIT

# 4. 验证版本
echo "🔍 验证当前版本..."
CURRENT_COMMIT=$(git rev-parse HEAD)
echo "当前提交: $CURRENT_COMMIT"

if [ "$CURRENT_COMMIT" = "$TARGET_COMMIT" ]; then
    echo "✅ 版本还原成功"
else
    echo "❌ 版本还原失败"
    echo "期望: $TARGET_COMMIT"
    echo "实际: $CURRENT_COMMIT"
    exit 1
fi

# 5. 显示当前状态
echo ""
echo "📋 当前代码状态:"
echo "提交信息: $(git log -1 --oneline)"
echo "分支: $(git branch --show-current)"
echo "远程状态: $(git status --porcelain)"

# 6. 检查关键文件
echo ""
echo "📁 检查关键文件:"
echo "src/index.ts: $([ -f src/index.ts ] && echo '✅ 存在' || echo '❌ 不存在')"
echo "Dockerfile: $([ -f Dockerfile ] && echo '✅ 存在' || echo '❌ 不存在')"
echo "docker-compose.ultra-optimized.yml: $([ -f docker-compose.ultra-optimized.yml ] && echo '✅ 存在' || echo '❌ 不存在')"
echo "package.json: $([ -f package.json ] && echo '✅ 存在' || echo '❌ 不存在')"

# 7. 重新构建服务
echo ""
echo "🔨 重新构建服务..."
if [ -f docker-compose.ultra-optimized.yml ]; then
    echo "使用 ultra-optimized 配置构建..."
    docker-compose -f docker-compose.ultra-optimized.yml build --no-cache
    
    if [ $? -eq 0 ]; then
        echo "✅ 镜像构建成功"
        
        # 启动服务
        echo "🚀 启动服务..."
        docker-compose -f docker-compose.ultra-optimized.yml up -d
        
        # 等待服务启动
        echo "⏳ 等待服务启动..."
        sleep 20
        
        # 检查服务状态
        echo "🔍 检查服务状态..."
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        
        # 测试服务
        echo ""
        echo "🧪 测试服务..."
        if curl -s --max-time 15 http://localhost:9200/api > /dev/null; then
            echo "✅ 服务响应正常"
            echo "📍 服务地址: http://localhost:9200"
        else
            echo "❌ 服务无响应，查看日志:"
            docker-compose -f docker-compose.ultra-optimized.yml logs --tail 20
        fi
        
    else
        echo "❌ 镜像构建失败"
    fi
    
elif [ -f docker-compose.yml ]; then
    echo "使用默认配置构建..."
    docker-compose build --no-cache
    docker-compose up -d
    
else
    echo "❌ 未找到Docker Compose配置文件"
fi

echo ""
echo "=== 强制还原完成 ==="
echo ""
echo "📋 管理命令:"
echo "  查看日志: docker-compose -f docker-compose.ultra-optimized.yml logs -f"
echo "  重启服务: docker-compose -f docker-compose.ultra-optimized.yml restart"
echo "  停止服务: docker-compose -f docker-compose.ultra-optimized.yml down"
echo ""
echo "🎯 目标版本: $TARGET_COMMIT"
echo "✅ 还原完成"
