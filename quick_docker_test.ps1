# Quick Docker Configuration Test Script
# Fast validation of all docker-compose configurations

param(
    [string]$ConfigOnly = "",  # Test only specific config
    [switch]$SkipBuild = $false  # Skip build step for faster testing
)

# Colors
$Colors = @{
    Red = "Red"; Green = "Green"; Yellow = "Yellow"; Blue = "Blue"; White = "White"
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $time = Get-Date -Format "HH:mm:ss"
    switch ($Level) {
        "INFO" { Write-Host "[$time] $Message" -ForegroundColor $Colors.Blue }
        "SUCCESS" { Write-Host "[$time] ✅ $Message" -ForegroundColor $Colors.Green }
        "ERROR" { Write-Host "[$time] ❌ $Message" -ForegroundColor $Colors.Red }
        "WARNING" { Write-Host "[$time] ⚠️ $Message" -ForegroundColor $Colors.Yellow }
    }
}

function Quick-Cleanup {
    Write-Log "Quick cleanup..." "INFO"
    $files = @("docker-compose.yml", "docker-compose.low-spec.yml", "docker-compose.high-performance.yml", "docker-compose.ultra-performance.yml", "docker-compose.prod.yml")
    foreach ($file in $files) {
        if (Test-Path $file) {
            docker-compose -f $file down --timeout 5 2>$null | Out-Null
        }
    }
    Remove-Item "quick_test_*.png" -Force -ErrorAction SilentlyContinue
}

function Quick-Wait {
    param([int]$MaxSeconds = 30)
    Write-Log "Waiting for service..." "INFO"
    for ($i = 1; $i -le $MaxSeconds; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:9200/api" -TimeoutSec 2 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                Write-Log "Service ready in ${i}s" "SUCCESS"
                return $true
            }
        } catch { }
        Write-Host "." -NoNewline
        Start-Sleep 1
    }
    Write-Host ""
    return $false
}

function Quick-Test {
    param([string]$ConfigName)
    
    # Basic API test
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:9200/api" -TimeoutSec 3
        if ($response.StatusCode -ne 200) { return $false }
    } catch { return $false }
    
    # Quick card generation test
    $testFile = "quick_test_$ConfigName.png"
    $body = @{
        temp = "tempA"
        color = "light-color-1"
        title = "Quick Test"
        date = (Get-Date -Format "yyyy/MM/dd HH:mm")
        content = "Quick test for $ConfigName"
        foreword = "Test"
        author = "Auto"
        switchConfig = @{
            showIcon = "false"
            showForeword = "false"
            showQRCode = "false"
        }
    } | ConvertTo-Json -Depth 2
    
    try {
        Invoke-WebRequest -Uri "http://localhost:9200/api/saveImg" -Method POST -ContentType "application/json" -Body $body -OutFile $testFile -TimeoutSec 30
        if ((Test-Path $testFile) -and ((Get-Item $testFile).Length -gt 0)) {
            $size = [math]::Round((Get-Item $testFile).Length / 1KB, 1)
            Write-Log "$ConfigName test passed (${size}KB)" "SUCCESS"
            return $true
        }
    } catch { }
    return $false
}

function Test-SingleConfig {
    param([string]$ConfigFile, [string]$ConfigName)
    
    Write-Host ""
    Write-Host "=== Testing $ConfigName ===" -ForegroundColor $Colors.White
    
    # Build if needed
    if (-not $SkipBuild) {
        Write-Log "Building..." "INFO"
        $buildOutput = docker-compose -f $ConfigFile build 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Build failed for $ConfigName" "ERROR"
            return $false
        }
    }
    
    # Start service
    Write-Log "Starting service..." "INFO"
    $upOutput = docker-compose -f $ConfigFile up -d 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Startup failed for $ConfigName" "ERROR"
        return $false
    }
    
    # Wait and test
    if (Quick-Wait) {
        $result = Quick-Test $ConfigName
        if ($result) {
            Write-Log "$ConfigName PASSED" "SUCCESS"
        } else {
            Write-Log "$ConfigName FAILED" "ERROR"
        }
    } else {
        Write-Log "$ConfigName service timeout" "ERROR"
        $result = $false
    }
    
    # Quick shutdown
    docker-compose -f $ConfigFile down --timeout 5 2>$null | Out-Null
    
    return $result
}

# Main execution
Write-Host "🚀 Quick Docker Configuration Test" -ForegroundColor $Colors.Green
Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor $Colors.Blue

Quick-Cleanup

# Define configurations
$configs = @{
    "docker-compose.yml" = "Standard"
    "docker-compose.low-spec.yml" = "LowSpec"
    "docker-compose.high-performance.yml" = "HighPerf"
    "docker-compose.ultra-performance.yml" = "UltraPerf"
    "docker-compose.prod.yml" = "Production"
}

$totalTests = 0
$passedTests = 0
$results = @{}

# Test configurations
foreach ($configFile in $configs.Keys) {
    $configName = $configs[$configFile]
    
    # Skip if specific config requested and this isn't it
    if ($ConfigOnly -and $configName -ne $ConfigOnly) { continue }
    
    if (Test-Path $configFile) {
        $totalTests++
        $startTime = Get-Date
        
        if (Test-SingleConfig $configFile $configName) {
            $passedTests++
            $results[$configName] = "PASS"
        } else {
            $results[$configName] = "FAIL"
        }
        
        $duration = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
        Write-Log "$configName completed in ${duration}s" "INFO"
        
        Start-Sleep 1  # Brief pause between tests
    } else {
        Write-Log "$configFile not found" "WARNING"
    }
}

Quick-Cleanup

# Results summary
Write-Host ""
Write-Host "=== RESULTS SUMMARY ===" -ForegroundColor $Colors.White
Write-Host "Total: $totalTests | Passed: $passedTests | Failed: $($totalTests - $passedTests)"

foreach ($config in $results.Keys) {
    $status = $results[$config]
    $color = if ($status -eq "PASS") { $Colors.Green } else { $Colors.Red }
    $icon = if ($status -eq "PASS") { "[PASS]" } else { "[FAIL]" }
    Write-Host "$icon $config : $status" -ForegroundColor $color
}

# Show generated files
$testFiles = Get-ChildItem -Name "quick_test_*.png" -ErrorAction SilentlyContinue
if ($testFiles) {
    Write-Host ""
    Write-Host "Generated test files:"
    foreach ($file in $testFiles) {
        $size = [math]::Round((Get-Item $file).Length / 1KB, 1)
        Write-Host "  📄 $file (${size}KB)" -ForegroundColor $Colors.Blue
    }
}

if ($passedTests -eq $totalTests -and $totalTests -gt 0) {
    Write-Host ""
    Write-Host "🎉 ALL TESTS PASSED!" -ForegroundColor $Colors.Green
    exit 0
} else {
    Write-Host ""
    Write-Host "❌ SOME TESTS FAILED" -ForegroundColor $Colors.Red
    exit 1
}
