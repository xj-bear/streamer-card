# 综合测试脚本 - 本地和Docker环境
param(
    [string]$Mode = "local", # local, docker-low-spec, docker-standard
    [string]$TestData = "test_data.json"
)

Write-Host "🚀 开始综合测试 - 模式: $Mode" -ForegroundColor Green

# 检查测试数据文件
if (-not (Test-Path $TestData)) {
    Write-Host "❌ 测试数据文件不存在: $TestData" -ForegroundColor Red
    exit 1
}

$testJson = Get-Content $TestData -Raw
Write-Host "✅ 测试数据已加载" -ForegroundColor Green

# 根据模式设置不同的测试参数
switch ($Mode) {
    "local" {
        $port = 3003
        $baseUrl = "http://localhost:$port"
        Write-Host "📍 本地测试模式 - 端口: $port" -ForegroundColor Yellow
        
        # 启动本地服务
        Write-Host "🔄 启动本地服务..." -ForegroundColor Yellow
        Start-Process powershell -ArgumentList "-Command", "npm run dev" -WindowStyle Minimized
        Start-Sleep 10
    }
    "docker-low-spec" {
        $port = 9200
        $baseUrl = "http://localhost:$port"
        Write-Host "📍 Docker低配置测试模式 - 端口: $port" -ForegroundColor Yellow
        
        # 启动Docker低配置服务
        Write-Host "🔄 启动Docker低配置服务..." -ForegroundColor Yellow
        docker-compose -f docker-compose.low-spec.yml down
        docker-compose -f docker-compose.low-spec.yml up -d
        Start-Sleep 30
    }
    "docker-standard" {
        $port = 9200
        $baseUrl = "http://localhost:$port"
        Write-Host "📍 Docker标准测试模式 - 端口: $port" -ForegroundColor Yellow
        
        # 启动Docker标准服务
        Write-Host "🔄 启动Docker标准服务..." -ForegroundColor Yellow
        docker-compose down
        docker-compose up -d
        Start-Sleep 30
    }
}

# 等待服务启动
Write-Host "⏳ 等待服务启动..." -ForegroundColor Yellow
$maxWait = 60
$waited = 0
$serviceStarted = $false

while ($waited -lt $maxWait -and -not $serviceStarted) {
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api" -Method Get -TimeoutSec 5
        if ($response -eq "hello world") {
            Write-Host "✅ 服务已启动" -ForegroundColor Green
            $serviceStarted = $true
            break
        }
    }
    catch {
        Start-Sleep 2
        $waited += 2
        Write-Host "⏳ 等待服务启动... ($waited/$maxWait 秒)" -ForegroundColor Yellow
    }
}

if (-not $serviceStarted) {
    Write-Host "❌ 服务启动超时" -ForegroundColor Red
    exit 1
}

# 执行测试
Write-Host "🧪 开始执行API测试..." -ForegroundColor Yellow

$startTime = Get-Date
try {
    # 测试API调用
    $headers = @{
        "Content-Type" = "application/json"
    }
    
    Write-Host "📤 发送测试请求..." -ForegroundColor Yellow
    $response = Invoke-RestMethod -Uri "$baseUrl/api/saveImg" -Method Post -Body $testJson -Headers $headers -TimeoutSec 120
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    # 保存结果图片
    $outputFile = "test_result_${Mode}_$(Get-Date -Format 'yyyyMMdd_HHmmss').png"
    [System.IO.File]::WriteAllBytes($outputFile, $response)
    
    Write-Host "✅ 测试成功完成!" -ForegroundColor Green
    Write-Host "⏱️  生成时间: $([math]::Round($duration, 2)) 秒" -ForegroundColor Green
    Write-Host "📁 输出文件: $outputFile" -ForegroundColor Green
    
    # 检查文件大小
    $fileSize = (Get-Item $outputFile).Length
    Write-Host "📊 文件大小: $([math]::Round($fileSize / 1KB, 2)) KB" -ForegroundColor Green
    
}
catch {
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    Write-Host "❌ 测试失败!" -ForegroundColor Red
    Write-Host "⏱️  失败时间: $([math]::Round($duration, 2)) 秒" -ForegroundColor Red
    Write-Host "🔍 错误信息: $($_.Exception.Message)" -ForegroundColor Red
}

# 清理
if ($Mode -eq "local") {
    Write-Host "🧹 停止本地服务..." -ForegroundColor Yellow
    Get-Process | Where-Object {$_.ProcessName -eq "node"} | Stop-Process -Force -ErrorAction SilentlyContinue
}

Write-Host "🏁 测试完成" -ForegroundColor Green
