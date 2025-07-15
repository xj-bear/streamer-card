# 性能测试脚本
Write-Host "🚀 开始性能测试..." -ForegroundColor Green

# 读取测试数据
$testJson = Get-Content "test_data.json" -Raw
$headers = @{
    "Content-Type" = "application/json"
}

# 测试API连通性
Write-Host "📡 测试API连通性..." -ForegroundColor Yellow
try {
    $apiResponse = Invoke-RestMethod -Uri "http://localhost:9200/api" -Method Get -TimeoutSec 10
    Write-Host "✅ API连通正常: $apiResponse" -ForegroundColor Green
} catch {
    Write-Host "❌ API连通失败: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 开始性能测试
Write-Host "⏱️  开始图片生成性能测试..." -ForegroundColor Yellow
$startTime = Get-Date

try {
    $response = Invoke-RestMethod -Uri "http://localhost:9200/api/saveImg" -Method Post -Body $testJson -Headers $headers -TimeoutSec 180
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    # 保存结果
    $outputFile = "performance_test_result.png"
    [System.IO.File]::WriteAllBytes($outputFile, $response)
    
    # 显示结果
    Write-Host "✅ 测试成功完成!" -ForegroundColor Green
    Write-Host "⏱️  生成时间: $([math]::Round($duration, 2)) 秒" -ForegroundColor Green
    
    $fileSize = (Get-Item $outputFile).Length
    Write-Host "📊 文件大小: $([math]::Round($fileSize / 1KB, 2)) KB" -ForegroundColor Green
    
    # 性能评估
    if ($duration -lt 15) {
        Write-Host "🚀 性能优秀! (< 15秒)" -ForegroundColor Green
    } elseif ($duration -lt 20) {
        Write-Host "✅ 性能良好! (15-20秒)" -ForegroundColor Yellow
    } elseif ($duration -lt 26) {
        Write-Host "⚠️  性能一般 (20-26秒)" -ForegroundColor Yellow
    } else {
        Write-Host "❌ 性能需要优化 (> 26秒)" -ForegroundColor Red
    }
    
    # 与之前26秒对比
    $improvement = ((26 - $duration) / 26) * 100
    if ($improvement -gt 0) {
        Write-Host "📈 性能提升: $([math]::Round($improvement, 1))%" -ForegroundColor Green
    } else {
        Write-Host "📉 性能下降: $([math]::Round(-$improvement, 1))%" -ForegroundColor Red
    }
    
} catch {
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    Write-Host "❌ 测试失败!" -ForegroundColor Red
    Write-Host "⏱️  失败时间: $([math]::Round($duration, 2)) 秒" -ForegroundColor Red
    Write-Host "🔍 错误信息: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "🏁 测试完成" -ForegroundColor Green
