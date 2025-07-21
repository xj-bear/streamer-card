Write-Host "Testing DingTalk JinBuTi font..." -ForegroundColor Green

$testData = Get-Content -Path "test_dingtalk_font.json" -Raw -Encoding UTF8
$uri = "http://localhost:9200/api/saveImg"
$outputFile = "dingtalk_font_test.png"

try {
    $startTime = Get-Date
    
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("Content-Type", "application/json; charset=utf-8")
    $webClient.Encoding = [System.Text.Encoding]::UTF8
    
    $responseBytes = $webClient.UploadData($uri, "POST", [System.Text.Encoding]::UTF8.GetBytes($testData))
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    [System.IO.File]::WriteAllBytes($outputFile, $responseBytes)
    
    $fileSize = (Get-Item $outputFile).Length
    Write-Host "DingTalk font test completed!" -ForegroundColor Green
    Write-Host "Processing time: $([math]::Round($duration, 2)) seconds" -ForegroundColor Cyan
    Write-Host "File size: $([math]::Round($fileSize/1KB, 2)) KB" -ForegroundColor Cyan
    Write-Host "Saved as: $outputFile" -ForegroundColor Cyan
    
    $webClient.Dispose()
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($webClient) { $webClient.Dispose() }
}

Write-Host ""
Write-Host "Testing Alibaba-PuHuiTi-Regular font..." -ForegroundColor Green

$testData2 = Get-Content -Path "test_alibaba_font.json" -Raw -Encoding UTF8
$outputFile2 = "alibaba_font_test.png"

try {
    $startTime = Get-Date
    
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("Content-Type", "application/json; charset=utf-8")
    $webClient.Encoding = [System.Text.Encoding]::UTF8
    
    $responseBytes = $webClient.UploadData($uri, "POST", [System.Text.Encoding]::UTF8.GetBytes($testData2))
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    [System.IO.File]::WriteAllBytes($outputFile2, $responseBytes)
    
    $fileSize = (Get-Item $outputFile2).Length
    Write-Host "Alibaba font test completed!" -ForegroundColor Green
    Write-Host "Processing time: $([math]::Round($duration, 2)) seconds" -ForegroundColor Cyan
    Write-Host "File size: $([math]::Round($fileSize/1KB, 2)) KB" -ForegroundColor Cyan
    Write-Host "Saved as: $outputFile2" -ForegroundColor Cyan
    
    $webClient.Dispose()
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($webClient) { $webClient.Dispose() }
}

Write-Host ""
Write-Host "Please check both images for black edge differences:" -ForegroundColor Yellow
Write-Host "- $outputFile (DingTalk JinBuTi)" -ForegroundColor White
Write-Host "- $outputFile2 (Alibaba-PuHuiTi-Regular)" -ForegroundColor White
