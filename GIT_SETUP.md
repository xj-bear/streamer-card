# Git 仓库设置指南

## 1. 创建您自己的 GitHub 仓库

### 步骤 1: 在 GitHub 上创建新仓库
1. 登录 GitHub
2. 点击右上角的 "+" 号，选择 "New repository"
3. 仓库名称: `streamer-card` (或您喜欢的名称)
4. 描述: `流光卡片 API - 修复版 (支持长内容完整显示)`
5. 选择 "Public" 或 "Private"
6. **不要**勾选 "Initialize this repository with a README"
7. 点击 "Create repository"

### 步骤 2: 更改本地仓库的远程地址
```bash
# 查看当前远程地址
git remote -v

# 移除原有的远程地址
git remote remove origin

# 添加您的新仓库地址 (替换为您的用户名和仓库名)
git remote add origin https://github.com/您的用户名/streamer-card.git

# 验证新的远程地址
git remote -v
```

### 步骤 3: 提交并推送代码
```bash
# 添加所有修改的文件
git add .

# 提交修改
git commit -m "feat: 修复长内容截取不完整问题并优化Docker部署

- 修复长内容卡片截取不完整问题
- 优化图片加载等待机制
- 增强内容完整性检查
- 改进Docker部署配置
- 支持Linux服务器部署
- 添加自动化测试脚本"

# 推送到您的仓库
git push -u origin main
```

## 2. 可选：保留原作者信息

如果您想在 README 中保留原作者信息，可以添加以下内容：

```markdown
## 致谢

本项目基于 [ygh3279799773/streamer-card](https://github.com/ygh3279799773/streamer-card) 进行修复和优化。

感谢原作者的开源贡献！
```

## 3. 分支管理建议

```bash
# 创建开发分支
git checkout -b develop

# 创建功能分支
git checkout -b feature/new-feature

# 合并到主分支
git checkout main
git merge develop
```

## 4. 标签管理

```bash
# 创建版本标签
git tag -a v1.1.0 -m "修复版本 v1.1.0 - 长内容显示完整"

# 推送标签
git push origin v1.1.0
```

## 5. 注意事项

- 确保不要推送敏感信息（如API密钥）
- 使用 `.gitignore` 忽略不必要的文件
- 定期备份重要的修改
- 考虑使用 GitHub Actions 进行自动化部署
