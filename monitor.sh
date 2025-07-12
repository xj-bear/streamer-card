#!/bin/bash

echo "=== 流光卡片服务器监控 ==="
echo ""

# 检查系统资源
echo "📊 系统资源使用情况:"
echo "内存使用:"
free -h
echo ""

echo "CPU使用:"
top -bn1 | grep "Cpu(s)" | awk '{print $2 $3 $4 $5 $6 $7 $8}'
echo ""

echo "磁盘使用:"
df -h | grep -E '^/dev/'
echo ""

# 检查Docker容器状态
echo "🐳 Docker容器状态:"
if command -v docker &> /dev/null; then
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    
    # 检查容器资源使用
    echo "📈 容器资源使用:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
    echo ""
else
    echo "Docker 未安装"
fi

# 检查服务状态
echo "🔍 服务健康检查:"
if curl -s --max-time 10 http://localhost:3003/api > /dev/null; then
    echo "✅ 服务运行正常"
else
    echo "❌ 服务异常"
    
    # 检查容器日志
    echo "📋 最近的错误日志:"
    docker logs --tail 20 streamer-card-low-spec 2>/dev/null || docker logs --tail 20 streamer-card 2>/dev/null
fi

echo ""

# 检查活跃连接数
echo "🌐 网络连接:"
netstat -an | grep :3003 | wc -l | xargs echo "端口3003活跃连接数:"

echo ""

# 内存警告
MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}')
if [ "$MEMORY_USAGE" -gt 85 ]; then
    echo "⚠️  警告: 内存使用率过高 (${MEMORY_USAGE}%)"
    echo "建议重启服务: docker-compose restart"
fi

# CPU警告
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
    echo "⚠️  警告: CPU使用率过高 (${CPU_USAGE}%)"
fi

echo ""
echo "=== 监控完成 ==="
echo "提示: 可以使用 'watch -n 5 ./monitor.sh' 进行实时监控"
