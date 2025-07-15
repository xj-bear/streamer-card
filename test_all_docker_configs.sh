#!/bin/bash

# 流光卡片 Docker 配置全面测试脚本
# 测试所有 docker-compose 配置文件

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 清理函数
cleanup() {
    log_info "清理测试环境..."
    docker-compose -f docker-compose.yml down --remove-orphans 2>/dev/null || true
    docker-compose -f docker-compose.low-spec.yml down --remove-orphans 2>/dev/null || true
    docker-compose -f docker-compose.high-performance.yml down --remove-orphans 2>/dev/null || true
    docker-compose -f docker-compose.ultra-performance.yml down --remove-orphans 2>/dev/null || true
    docker-compose -f docker-compose.prod.yml down --remove-orphans 2>/dev/null || true
    
    # 清理测试生成的图片
    rm -f test_*.png api_test_*.png
    
    log_success "环境清理完成"
}

# 等待服务启动
wait_for_service() {
    local max_attempts=30
    local attempt=1
    
    log_info "等待服务启动..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:9200/api > /dev/null 2>&1; then
            log_success "服务已启动 (尝试 $attempt/$max_attempts)"
            return 0
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log_error "服务启动超时"
    return 1
}

# 测试API功能
test_api() {
    local config_name=$1
    
    log_info "测试 $config_name API 功能..."
    
    # 测试基础API
    if ! curl -s http://localhost:9200/api > /dev/null; then
        log_error "$config_name 基础API测试失败"
        return 1
    fi
    
    # 测试卡片生成
    local test_file="test_${config_name}.png"
    
    curl -X POST http://localhost:9200/api/saveImg \
      -H "Content-Type: application/json" \
      -d '{
        "temp": "tempB",
        "color": "dark-color-2",
        "title": "🧪 Docker 测试 - '"$config_name"'",
        "date": "'"$(date '+%Y/%m/%d %H:%M')"'",
        "content": "这是 '"$config_name"' 配置的测试卡片。\n\n**测试信息：**\n- 配置: '"$config_name"'\n- 时间: '"$(date)"'\n- 状态: 正常运行",
        "foreword": "Docker 配置测试",
        "author": "自动化测试",
        "qrcodetitle": "测试二维码",
        "qrcodetext": "扫描测试",
        "qrcode": "https://github.com/xj-bear/streamer-card",
        "watermark": "'"$config_name"' 测试",
        "switchConfig": {
          "showIcon": "false",
          "showForeword": "true",
          "showQRCode": "true"
        }
      }' \
      --output "$test_file" \
      --max-time 120
    
    if [ -f "$test_file" ] && [ -s "$test_file" ]; then
        local file_size=$(ls -lh "$test_file" | awk '{print $5}')
        log_success "$config_name 卡片生成成功！文件大小: $file_size"
        return 0
    else
        log_error "$config_name 卡片生成失败"
        return 1
    fi
}

# 测试单个配置
test_config() {
    local config_file=$1
    local config_name=$2
    
    echo ""
    echo "=========================================="
    log_info "开始测试配置: $config_name"
    log_info "配置文件: $config_file"
    echo "=========================================="
    
    # 构建镜像
    log_info "构建 Docker 镜像..."
    if ! docker-compose -f "$config_file" build; then
        log_error "$config_name 镜像构建失败"
        return 1
    fi
    log_success "$config_name 镜像构建完成"
    
    # 启动服务
    log_info "启动 $config_name 服务..."
    if ! docker-compose -f "$config_file" up -d; then
        log_error "$config_name 服务启动失败"
        return 1
    fi
    log_success "$config_name 服务启动完成"
    
    # 等待服务就绪
    if ! wait_for_service; then
        log_error "$config_name 服务就绪检查失败"
        docker-compose -f "$config_file" logs
        docker-compose -f "$config_file" down
        return 1
    fi
    
    # 测试API
    if test_api "$config_name"; then
        log_success "$config_name 测试通过"
        test_result=0
    else
        log_error "$config_name 测试失败"
        test_result=1
    fi
    
    # 显示容器状态
    log_info "$config_name 容器状态:"
    docker-compose -f "$config_file" ps
    
    # 显示资源使用情况
    log_info "$config_name 资源使用情况:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
    
    # 停止服务
    log_info "停止 $config_name 服务..."
    docker-compose -f "$config_file" down
    
    return $test_result
}

# 主测试流程
main() {
    echo "🚀 开始 Docker 配置全面测试"
    echo "测试时间: $(date)"
    echo ""
    
    # 清理环境
    cleanup
    
    # 定义测试配置
    declare -A configs=(
        ["docker-compose.yml"]="标准配置"
        ["docker-compose.low-spec.yml"]="低配置"
        ["docker-compose.high-performance.yml"]="高性能配置"
        ["docker-compose.ultra-performance.yml"]="超高性能配置"
        ["docker-compose.prod.yml"]="生产配置"
    )
    
    local total_tests=0
    local passed_tests=0
    local failed_configs=()
    
    # 逐个测试配置
    for config_file in "${!configs[@]}"; do
        if [ -f "$config_file" ]; then
            total_tests=$((total_tests + 1))
            
            if test_config "$config_file" "${configs[$config_file]}"; then
                passed_tests=$((passed_tests + 1))
            else
                failed_configs+=("${configs[$config_file]}")
            fi
            
            # 测试间隔
            sleep 5
        else
            log_warning "配置文件 $config_file 不存在，跳过测试"
        fi
    done
    
    # 最终清理
    cleanup
    
    # 测试结果汇总
    echo ""
    echo "=========================================="
    echo "🎯 测试结果汇总"
    echo "=========================================="
    echo "总测试数: $total_tests"
    echo "通过测试: $passed_tests"
    echo "失败测试: $((total_tests - passed_tests))"
    
    if [ ${#failed_configs[@]} -eq 0 ]; then
        log_success "🎉 所有配置测试通过！"
        echo ""
        echo "📋 测试的配置:"
        for config_file in "${!configs[@]}"; do
            if [ -f "$config_file" ]; then
                echo "  ✅ ${configs[$config_file]} ($config_file)"
            fi
        done
        
        echo ""
        echo "🔍 生成的测试文件:"
        ls -la test_*.png 2>/dev/null || echo "  (无测试文件生成)"
        
        exit 0
    else
        log_error "❌ 部分配置测试失败"
        echo ""
        echo "失败的配置:"
        for config in "${failed_configs[@]}"; do
            echo "  ❌ $config"
        done
        exit 1
    fi
}

# 捕获中断信号
trap cleanup EXIT INT TERM

# 执行主流程
main "$@"
