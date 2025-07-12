# 流光卡片 API 本地部署指南

## 🎉 部署成功！

您的流光卡片 API 已成功部署在本机。以下是使用指南：

## 📋 快速开始

### 启动服务
```bash
./start.sh
```

### 停止服务
```bash
./stop.sh
```

### 测试 API
```bash
./test_api.sh
```

## 🌐 API 信息

- **服务地址**: http://localhost:3003
- **端口**: 3003

## 📚 API 端点

### 1. 基础测试端点
```
GET /api
```
返回: `hello world`

### 2. 生成卡片
```
POST /api/saveImg
Content-Type: application/json
```

#### 请求示例
```json
{
  "temp": "tempB",
  "color": "dark-color-2",
  "title": "👋 你好，世界！",
  "date": "2024/7/12 11:30",
  "content": "这是一个精美的卡片示例。\n\n**支持 Markdown 语法**",
  "foreword": "卡片前言",
  "author": "作者名称",
  "qrcodetitle": "二维码标题",
  "qrcodetext": "二维码描述",
  "qrcode": "https://example.com",
  "watermark": "水印文字",
  "switchConfig": {
    "showIcon": "false",
    "showForeword": "true",
    "showQRCode": "true"
  }
}
```

### 3. 生成带广告的卡片
```
POST /api/wxSaveImg
Content-Type: application/json
```
（参数同上，但会自动添加随机广告二维码）

## 🎨 支持的模板

- `tempA` - 模板A
- `tempB` - 模板B  
- `tempC` - 模板C

## 🎨 支持的颜色

- `dark-color-1`, `dark-color-2`
- `light-blue-color-1` 到 `light-blue-color-16`
- `light-red-color-1` 到 `light-red-color-16`
- `light-green-color-1` 到 `light-green-color-15`

## 🔧 自定义配置

### switchConfig 选项
- `showIcon`: 显示图标 ("true"/"false")
- `showDate`: 显示日期 ("true"/"false")
- `showTitle`: 显示标题 ("true"/"false")
- `showContent`: 显示内容 ("true"/"false")
- `showAuthor`: 显示作者 ("true"/"false")
- `showTextCount`: 显示文字计数 ("true"/"false")
- `showQRCode`: 显示二维码 ("true"/"false")
- `showForeword`: 显示前言 ("true"/"false")

### 其他选项
- `width`: 卡片宽度 (最小 300px)
- `height`: 卡片高度
- `padding`: 内边距
- `fontScale`: 字体缩放比例 (如 1.2, 1.4)
- `imgScale`: 图片清晰度 (默认 2)
- `isContentHtml`: 是否使用 HTML 解析 (默认 false，使用 Markdown)

## 📁 项目结构

```
streamer-card/
├── src/
│   └── index.ts          # 主服务文件
├── assets/               # 静态资源
├── start.sh             # 启动脚本
├── stop.sh              # 停止脚本
├── test_api.sh          # 测试脚本
├── package.json         # 项目配置
└── README.md            # 项目说明
```

## 🛠️ 故障排除

### 1. 端口被占用
```bash
# 查看端口占用情况
lsof -i :3003

# 停止服务
./stop.sh
```

### 2. Chrome 浏览器问题
如果遇到 Chrome 相关错误，请确保：
- Chrome 已正确安装在 `/Applications/Google Chrome.app/`
- 或者修改 `src/index.ts` 中的 `executablePath` 路径

### 3. 依赖问题
```bash
# 重新安装依赖
rm -rf node_modules package-lock.json
npm install
```

## 🚀 开发模式

```bash
# 开发模式启动（自动重启）
npm run dev
```

## 📝 日志查看

服务运行时的日志会直接输出到终端。如需查看详细日志，建议使用：

```bash
# 启动并保存日志
npx ts-node src/index.ts > app.log 2>&1 &
```

## 🎯 使用示例

### 使用 curl 测试
```bash
curl -X POST http://localhost:3003/api/saveImg \
  -H "Content-Type: application/json" \
  -d @request.json \
  --output card.png
```

### 使用 JavaScript 调用
```javascript
const response = await fetch('http://localhost:3003/api/saveImg', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    temp: 'tempB',
    color: 'dark-color-2',
    title: '测试卡片',
    content: '这是测试内容',
    // ... 其他参数
  })
});

const blob = await response.blob();
// 处理返回的图片数据
```

## 📞 技术支持

如果遇到问题，请：
1. 检查 Node.js 版本是否 >= 18
2. 确认 Chrome 浏览器已正确安装
3. 查看控制台错误信息
4. 参考项目原始 README 文档

---

🎉 **恭喜！您的流光卡片 API 已成功部署并可以使用了！** 