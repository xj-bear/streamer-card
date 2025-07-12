# 低配置服务器优化指南

## 🎯 针对2G2核服务器的优化方案

### 问题分析
在2G2核配置的服务器上，原始配置会导致：
- 内存不足导致系统卡死
- 过多并发请求耗尽资源
- Puppeteer进程占用过多内存
- 无限重试加重服务器负担

### 🔧 优化措施

#### 1. 并发控制
- **原始配置**: 最大并发10个
- **优化后**: 生产环境限制为2个并发
- **请求队列**: 超出并发限制的请求进入队列等待
- **超时机制**: 队列等待超过30秒自动超时

#### 2. 内存优化
- **缓存大小**: 从50MB降低到20MB
- **缓存项数**: 从100个降低到20个
- **缓存时间**: 从10分钟降低到5分钟
- **V8内存限制**: 设置为512MB

#### 3. Puppeteer优化
- **单进程模式**: 使用`--single-process`减少内存占用
- **禁用GPU**: 避免GPU相关的内存分配
- **内存压力检测**: 关闭内存压力检测
- **协议超时**: 从120秒降低到60秒

#### 4. Docker资源限制
- **内存限制**: 1.2GB (预留0.8GB给系统)
- **CPU限制**: 1.8核 (预留0.2核给系统)
- **共享内存**: 128MB (足够Chromium使用)

### 📊 性能对比

| 配置项 | 原始配置 | 优化配置 | 改进效果 |
|--------|----------|----------|----------|
| 最大并发 | 10个 | 2个 | 减少80%资源占用 |
| 内存缓存 | 50MB | 20MB | 减少60%内存使用 |
| 重试次数 | 3次 | 2次 | 减少33%重试负担 |
| 协议超时 | 120s | 60s | 更快失败恢复 |
| 容器内存 | 1GB | 1.2GB | 增加20%可用内存 |

### 🚀 部署步骤

#### 方式一：使用优化脚本（推荐）
```bash
# 下载项目
git clone https://github.com/您的用户名/streamer-card.git
cd streamer-card

# 运行低配置优化部署
./deploy-low-spec.sh
```

#### 方式二：手动部署
```bash
# 使用低配置Docker配置
docker-compose -f docker-compose.low-spec.yml up -d

# 监控资源使用
./monitor.sh
```

### 📈 监控和维护

#### 实时监控
```bash
# 实时监控资源使用
watch -n 5 ./monitor.sh

# 查看容器日志
docker-compose -f docker-compose.low-spec.yml logs -f

# 检查容器状态
docker stats
```

#### 性能调优
```bash
# 如果内存使用过高，重启服务
docker-compose -f docker-compose.low-spec.yml restart

# 清理Docker缓存
docker system prune -f

# 检查swap使用情况
free -h
```

### ⚠️ 注意事项

#### 系统要求
- **最低内存**: 2GB (推荐增加1GB swap)
- **最低CPU**: 2核
- **磁盘空间**: 至少5GB可用空间

#### 使用限制
- **并发限制**: 同时最多处理2个请求
- **队列超时**: 等待超过30秒的请求会被拒绝
- **重试次数**: 失败请求最多重试2次

#### 性能建议
1. **定期重启**: 建议每天重启一次服务释放内存
2. **监控资源**: 使用monitor.sh定期检查资源使用
3. **增加swap**: 内存不足时增加swap空间
4. **错峰使用**: 避免高峰期大量并发请求

### 🔧 故障排除

#### 常见问题

**1. 服务启动失败**
```bash
# 检查内存是否足够
free -h

# 检查端口是否被占用
netstat -tlnp | grep 3003

# 查看详细错误日志
docker-compose -f docker-compose.low-spec.yml logs
```

**2. 请求超时**
```bash
# 检查当前并发数
curl http://localhost:3003/api

# 查看队列状态（通过日志）
docker-compose -f docker-compose.low-spec.yml logs | grep "队列"
```

**3. 内存不足**
```bash
# 增加swap空间
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 重启服务
docker-compose -f docker-compose.low-spec.yml restart
```

### 📞 技术支持

如果遇到问题，请提供以下信息：
1. 服务器配置（内存、CPU）
2. 错误日志 (`docker-compose logs`)
3. 资源使用情况 (`./monitor.sh`)
4. 系统信息 (`free -h && nproc`)

通过这些优化，2G2核的服务器应该能够稳定运行流光卡片服务！
