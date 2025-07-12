#!/bin/bash

echo "🖼️  测试包含图片的卡片生成..."
echo "================================================"

# 发送请求并获取详细信息
echo "📤 发送请求..."
response=$(curl -X POST http://localhost:3003/api/saveImg \
  -H "Content-Type: application/json" \
  -d @test_image_json.json \
  --output test_image_detailed.png \
  -w "HTTP_STATUS:%{http_code};TIME_TOTAL:%{time_total};SIZE_DOWNLOAD:%{size_download};SIZE_UPLOAD:%{size_upload}" \
  -s)

echo "📊 请求结果:"
echo "HTTP状态码: $(echo $response | cut -d';' -f1 | cut -d':' -f2)"
echo "总耗时: $(echo $response | cut -d';' -f2 | cut -d':' -f2)秒"
echo "下载大小: $(echo $response | cut -d';' -f3 | cut -d':' -f2)字节"
echo "上传大小: $(echo $response | cut -d';' -f4 | cut -d':' -f2)字节"

echo ""
echo "🔍 生成的图片信息:"

if [ -f "test_image_detailed.png" ]; then
    echo "✅ 文件生成成功"
    echo "📁 文件大小: $(ls -lh test_image_detailed.png | awk '{print $5}')"
    echo "📐 图片尺寸: $(sips -g pixelWidth -g pixelHeight test_image_detailed.png | grep pixel | awk '{print $2}' | paste -sd 'x' -)"
    echo "🎨 图片格式: $(file test_image_detailed.png | cut -d':' -f2)"
    
    # 计算图片的宽高比
    width=$(sips -g pixelWidth test_image_detailed.png | grep pixelWidth | awk '{print $2}')
    height=$(sips -g pixelHeight test_image_detailed.png | grep pixelHeight | awk '{print $2}')
    ratio=$(echo "scale=2; $width / $height" | bc -l)
    echo "📏 宽高比: $ratio"
    
    echo ""
    echo "🎯 测试结果分析:"
    echo "- 图片宽度: ${width}px (请求宽度: 440px, 实际是 2x 缩放)"
    echo "- 图片高度: ${height}px (自适应高度)"
    
    if [ $height -gt 1000 ]; then
        echo "✅ 图片高度充足，应该包含完整内容"
    else
        echo "⚠️  图片高度较小，可能内容被截断"
    fi
    
    echo ""
    echo "💡 您可以使用以下命令查看生成的图片:"
    echo "   open test_image_detailed.png"
    
else
    echo "❌ 文件生成失败"
fi

echo ""
echo "================================================"
echo "🎉 测试完成！" 