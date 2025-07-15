# 低配置调试测试脚本
Write-Host "=== 低配置调试测试 ===" -ForegroundColor Green

# 测试API连通性
Write-Host "1. 测试API连通性..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:9200/api" -UseBasicParsing
    Write-Host "API状态: $($response.StatusCode) - $($response.Content)" -ForegroundColor Green
} catch {
    Write-Host "API测试失败: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 测试图片生成 - 最简单的请求
Write-Host "2. 测试图片生成..." -ForegroundColor Yellow

$testData = @{
    temp = "tempB"
    title = "Debug Test"
    content = "Simple content"
    author = "Test"
    date = "2025/07/14"
    color = "dark-color-2"
    switchConfig = @{
        showForeword = "false"
        showQRCode = "false"
        showIcon = "false"
    } | ConvertTo-Json -Compress
} | ConvertTo-Json -Depth 3

Write-Host "请求数据: $testData" -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri "http://localhost:9200/api/saveImg" -Method POST -Body $testData -ContentType "application/json" -UseBasicParsing -TimeoutSec 180
    
    if ($response.StatusCode -eq 200) {
        $filename = "debug_test_$(Get-Date -Format 'yyyyMMdd_HHmmss').png"
        [System.IO.File]::WriteAllBytes($filename, $response.Content)
        $fileSize = [math]::Round((Get-Item $filename).Length / 1KB, 2)
        Write-Host "图片生成成功! 文件: $filename, 大小: ${fileSize}KB" -ForegroundColor Green
    } else {
        Write-Host "图片生成失败，状态码: $($response.StatusCode)" -ForegroundColor Red
    }
} catch {
    Write-Host "图片生成异常: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "详细错误: $($_.Exception)" -ForegroundColor Red
}

Write-Host "=== 测试完成 ===" -ForegroundColor Green
