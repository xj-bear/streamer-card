#!/bin/bash

echo "=== 流光卡片低配置服务器部署脚本 ==="
echo "适用于 2G2核 或更低配置的服务器"
echo ""

# 检查系统资源
echo "🔍 检查系统资源..."
TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
CPU_CORES=$(nproc)

echo "系统内存: ${TOTAL_MEM}MB"
echo "CPU核心数: ${CPU_CORES}"

if [ "$TOTAL_MEM" -lt 1800 ]; then
    echo "⚠️  警告: 内存不足2GB，可能影响性能"
fi

if [ "$CPU_CORES" -lt 2 ]; then
    echo "⚠️  警告: CPU核心数不足2个，可能影响性能"
fi

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

# 优化系统设置
echo "⚙️  优化系统设置..."

# 增加swap文件（如果内存小于2GB）
if [ "$TOTAL_MEM" -lt 2000 ] && [ ! -f /swapfile ]; then
    echo "创建1GB swap文件..."
    sudo fallocate -l 1G /swapfile 2>/dev/null || sudo dd if=/dev/zero of=/swapfile bs=1024 count=1048576
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo "✅ Swap文件创建完成"
fi

# 优化内核参数
echo "优化内核参数..."
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

echo ""

# 停止现有容器
echo "🛑 停止现有容器..."
docker-compose -f docker-compose.low-spec.yml down 2>/dev/null || true
docker-compose down 2>/dev/null || true

# 清理Docker资源
echo "🧹 清理Docker资源..."
docker system prune -f
docker image prune -f

# 构建新镜像
echo "🔨 构建优化镜像..."
docker-compose -f docker-compose.low-spec.yml build --no-cache

# 启动服务
echo "🚀 启动低配置优化服务..."
docker-compose -f docker-compose.low-spec.yml up -d

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 30

# 检查服务状态
echo "🔍 检查服务状态..."
if curl -s --max-time 30 http://localhost:3003/api > /dev/null; then
    echo "✅ 服务启动成功！"
    echo ""
    echo "📍 服务信息:"
    echo "  API 地址: http://localhost:3003"
    echo "  健康检查: http://localhost:3003/api"
    echo ""
    echo "📋 管理命令:"
    echo "  查看日志: docker-compose -f docker-compose.low-spec.yml logs -f"
    echo "  停止服务: docker-compose -f docker-compose.low-spec.yml down"
    echo "  重启服务: docker-compose -f docker-compose.low-spec.yml restart"
    echo "  监控资源: ./monitor.sh"
    echo ""
    echo "⚠️  低配置服务器注意事项:"
    echo "  - 并发请求限制为2个"
    echo "  - 建议定期重启服务释放内存"
    echo "  - 使用 ./monitor.sh 监控资源使用"
else
    echo "❌ 服务启动失败，请检查日志:"
    echo "docker-compose -f docker-compose.low-spec.yml logs"
    echo ""
    echo "常见问题排查:"
    echo "1. 内存不足: 增加swap空间"
    echo "2. 端口占用: 检查3003端口是否被占用"
    echo "3. 权限问题: 确保Docker有足够权限"
fi

echo ""
echo "=== 部署完成 ==="
