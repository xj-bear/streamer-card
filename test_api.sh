#!/bin/bash

echo "🚀 开始测试流光卡片 API..."

# 测试基础 API
echo "📡 测试基础 API 端点..."
curl -s http://localhost:3003/api
echo ""

# 测试卡片生成
echo "🎨 测试卡片生成功能..."
curl -X POST http://localhost:3003/api/saveImg \
  -H "Content-Type: application/json" \
  -d '{
    "temp": "tempB",
    "color": "dark-color-2",
    "title": "👋 你好，世界！",
    "date": "2024/7/12 11:30",
    "content": "这是一个通过 API 生成的精美卡片示例。\n\n**支持功能：**\n- Markdown 语法\n- 多种模板\n- 自定义颜色\n- 二维码生成\n- 水印设置",
    "foreword": "API 测试成功",
    "author": "流光卡片 API",
    "qrcodetitle": "流光卡片",
    "qrcodetext": "扫描二维码访问",
    "qrcode": "https://fireflycard.shushiai.com/",
    "watermark": "Powered by 流萤卡片",
    "switchConfig": {
      "showIcon": "false",
      "showForeword": "true",
      "showQRCode": "true"
    }
  }' \
  --output api_test_card.png

if [ -f "api_test_card.png" ]; then
    echo "✅ 卡片生成成功！文件已保存为 api_test_card.png"
    echo "📊 文件大小: $(ls -lh api_test_card.png | awk '{print $5}')"
else
    echo "❌ 卡片生成失败"
fi

echo ""
echo "🎉 测试完成！"
echo "💡 您可以使用以下命令查看生成的卡片："
echo "   open api_test_card.png" 