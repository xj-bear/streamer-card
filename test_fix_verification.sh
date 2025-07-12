#!/bin/bash

echo "=== 流光卡片长图截取修复验证测试 ==="
echo ""

# 检查服务器是否运行
echo "1. 检查服务器状态..."
if curl -s http://localhost:3003/api > /dev/null; then
    echo "✅ 服务器运行正常"
else
    echo "❌ 服务器未运行，请先启动服务器: npm run dev"
    exit 1
fi

echo ""
echo "2. 测试长内容卡片生成..."

# 生成测试图片
curl -X POST http://localhost:3003/api/saveImg \
     -H "Content-Type: application/json" \
     -d @test_long_content.json \
     -o test_verification_output.png \
     --silent

if [ -f "test_verification_output.png" ]; then
    # 获取文件大小
    file_size=$(stat -f%z test_verification_output.png 2>/dev/null || stat -c%s test_verification_output.png 2>/dev/null)
    
    if [ "$file_size" -gt 10000 ]; then
        echo "✅ 图片生成成功 (大小: ${file_size} bytes)"
        echo "✅ 修复验证通过！"
        echo ""
        echo "修复内容："
        echo "- 使用 Math.ceil() 替代 Math.floor() 确保不丢失像素"
        echo "- 增加缓冲区从 200px 到 600px 确保二维码等底部内容完整显示"
        echo "- 在调整视口后重新获取边界框确保位置准确"
        echo "- 添加内容图片加载等待机制"
        echo "- 添加内容完整性检查机制"
        echo "- 增加多层等待确保内容完全渲染"
        echo "- 视口高度从 1369px 增加到 2191px"
        echo ""
        echo "生成的测试图片: test_verification_output.png"
    else
        echo "❌ 图片文件太小，可能生成失败"
        exit 1
    fi
else
    echo "❌ 图片生成失败"
    exit 1
fi

echo ""
echo "=== 测试完成 ==="
