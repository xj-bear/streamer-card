Write-Host "测试标准模式性能..." -ForegroundColor Green

$json = Get-Content "test_data.json" -Raw
$start = Get-Date

try {
    $result = Invoke-RestMethod -Uri "http://localhost:9200/api/saveImg" -Method POST -Body $json -ContentType "application/json"
    $end = Get-Date
    $duration = ($end - $start).TotalSeconds
    
    Write-Host "生成时间: $([math]::Round($duration, 2)) 秒" -ForegroundColor Green
    
    $improvement = ((20 - $duration) / 20) * 100
    if ($improvement -gt 0) {
        Write-Host "性能提升: $([math]::Round($improvement, 1))%" -ForegroundColor Green
    } else {
        Write-Host "性能下降: $([math]::Round(-$improvement, 1))%" -ForegroundColor Red
    }
    
} catch {
    Write-Host "错误: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "测试完成" -ForegroundColor Green
