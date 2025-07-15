# 简单性能测试
Write-Host "开始性能测试..." -ForegroundColor Green

$testJson = Get-Content "test_data.json" -Raw
$headers = @{"Content-Type" = "application/json"}

Write-Host "测试API连通性..." -ForegroundColor Yellow
try {
    $apiResponse = Invoke-RestMethod -Uri "http://localhost:9200/api" -Method Get -TimeoutSec 10
    Write-Host "API连通正常: $apiResponse" -ForegroundColor Green
} catch {
    Write-Host "API连通失败: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "开始图片生成测试..." -ForegroundColor Yellow
$startTime = Get-Date

try {
    $response = Invoke-RestMethod -Uri "http://localhost:9200/api/saveImg" -Method Post -Body $testJson -Headers $headers -TimeoutSec 180
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    $outputFile = "performance_test_result.png"
    [System.IO.File]::WriteAllBytes($outputFile, $response)
    
    Write-Host "测试成功完成!" -ForegroundColor Green
    Write-Host "生成时间: $([math]::Round($duration, 2)) 秒" -ForegroundColor Green
    
    $fileSize = (Get-Item $outputFile).Length
    Write-Host "文件大小: $([math]::Round($fileSize / 1KB, 2)) KB" -ForegroundColor Green
    
    $improvement = ((26 - $duration) / 26) * 100
    if ($improvement -gt 0) {
        Write-Host "性能提升: $([math]::Round($improvement, 1))%" -ForegroundColor Green
    } else {
        Write-Host "性能下降: $([math]::Round(-$improvement, 1))%" -ForegroundColor Red
    }
    
} catch {
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    Write-Host "测试失败!" -ForegroundColor Red
    Write-Host "失败时间: $([math]::Round($duration, 2)) 秒" -ForegroundColor Red
    Write-Host "错误信息: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "测试完成" -ForegroundColor Green
