# Streamer Card Docker Configuration Test Script (PowerShell Version)
# Test all docker-compose configuration files

param(
    [switch]$SkipCleanup = $false
)

# Color definitions
$Colors = @{
    Red = "Red"
    Green = "Green"
    Yellow = "Yellow"
    Blue = "Blue"
    White = "White"
}

# Logging functions
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    switch ($Level) {
        "INFO" { Write-Host "[$timestamp] [INFO] $Message" -ForegroundColor $Colors.Blue }
        "SUCCESS" { Write-Host "[$timestamp] [SUCCESS] $Message" -ForegroundColor $Colors.Green }
        "WARNING" { Write-Host "[$timestamp] [WARNING] $Message" -ForegroundColor $Colors.Yellow }
        "ERROR" { Write-Host "[$timestamp] [ERROR] $Message" -ForegroundColor $Colors.Red }
    }
}

# Cleanup function
function Invoke-Cleanup {
    Write-Log "Cleaning test environment..." "INFO"

    $composeFiles = @(
        "docker-compose.yml",
        "docker-compose.low-spec.yml",
        "docker-compose.high-performance.yml",
        "docker-compose.ultra-performance.yml",
        "docker-compose.prod.yml"
    )

    foreach ($file in $composeFiles) {
        if (Test-Path $file) {
            try {
                docker-compose -f $file down --remove-orphans 2>$null
            } catch {
                # Ignore errors
            }
        }
    }

    # Clean up test generated images
    Get-ChildItem -Path "." -Name "test_*.png" | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path "." -Name "api_test_*.png" | Remove-Item -Force -ErrorAction SilentlyContinue

    Write-Log "Environment cleanup completed" "SUCCESS"
}

# Wait for service to start (optimized for speed)
function Wait-ForService {
    param([int]$MaxAttempts = 15)  # Reduced from 30

    Write-Log "Waiting for service to start..." "INFO"

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:9200/api" -TimeoutSec 3 -ErrorAction Stop  # Reduced timeout
            if ($response.StatusCode -eq 200) {
                Write-Log "Service started (attempt $attempt/$MaxAttempts)" "SUCCESS"
                return $true
            }
        } catch {
            # Continue trying
        }

        Write-Host "." -NoNewline
        Start-Sleep -Seconds 1  # Reduced from 2 seconds
    }

    Write-Host ""
    Write-Log "Service startup timeout" "ERROR"
    return $false
}

# Test API functionality
function Test-Api {
    param([string]$ConfigName)

    Write-Log "Testing $ConfigName API functionality..." "INFO"

    # Test basic API (quick test)
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:9200/api" -TimeoutSec 5  # Reduced timeout
        if ($response.StatusCode -ne 200) {
            Write-Log "$ConfigName basic API test failed" "ERROR"
            return $false
        }
    } catch {
        Write-Log "$ConfigName basic API test failed: $($_.Exception.Message)" "ERROR"
        return $false
    }

    # Test card generation (simplified)
    $testFile = "test_$ConfigName.png"
    $currentDate = Get-Date -Format "yyyy/MM/dd HH:mm"

    $body = @{
        temp = "tempB"
        color = "dark-color-2"
        title = "Test - $ConfigName"
        date = $currentDate
        content = "Quick test for $ConfigName config.`n`n**Status:** OK"
        foreword = "Test"
        author = "Auto"
        qrcodetitle = "QR"
        qrcodetext = "Test"
        qrcode = "https://github.com/xj-bear/streamer-card"
        watermark = "$ConfigName"
        switchConfig = @{
            showIcon = "false"
            showForeword = "true"
            showQRCode = "false"  # Disable QR code for faster generation
        }
    } | ConvertTo-Json -Depth 3

    try {
        Invoke-WebRequest -Uri "http://localhost:9200/api/saveImg" `
            -Method POST `
            -ContentType "application/json" `
            -Body $body `
            -OutFile $testFile `
            -TimeoutSec 60  # Reduced timeout

        if ((Test-Path $testFile) -and ((Get-Item $testFile).Length -gt 0)) {
            $fileSize = [math]::Round((Get-Item $testFile).Length / 1KB, 2)
            Write-Log "$ConfigName card generation successful! File size: ${fileSize}KB" "SUCCESS"
            return $true
        } else {
            Write-Log "$ConfigName card generation failed" "ERROR"
            return $false
        }
    } catch {
        Write-Log "$ConfigName card generation failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Test single configuration
function Test-Config {
    param(
        [string]$ConfigFile,
        [string]$ConfigName
    )

    Write-Host ""
    Write-Host "==========================================" -ForegroundColor $Colors.White
    Write-Log "Starting test for configuration: $ConfigName" "INFO"
    Write-Log "Configuration file: $ConfigFile" "INFO"
    Write-Host "==========================================" -ForegroundColor $Colors.White

    # Build image
    Write-Log "Building Docker image..." "INFO"
    try {
        $buildResult = docker-compose -f $ConfigFile build 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "$ConfigName image build failed" "ERROR"
            Write-Host $buildResult
            return $false
        }
        Write-Log "$ConfigName image build completed" "SUCCESS"
    } catch {
        Write-Log "$ConfigName image build failed: $($_.Exception.Message)" "ERROR"
        return $false
    }

    # Start service
    Write-Log "Starting $ConfigName service..." "INFO"
    try {
        $upResult = docker-compose -f $ConfigFile up -d 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "$ConfigName service startup failed" "ERROR"
            Write-Host $upResult
            return $false
        }
        Write-Log "$ConfigName service startup completed" "SUCCESS"
    } catch {
        Write-Log "$ConfigName service startup failed: $($_.Exception.Message)" "ERROR"
        return $false
    }

    # Wait for service readiness
    if (-not (Wait-ForService)) {
        Write-Log "$ConfigName service readiness check failed" "ERROR"
        docker-compose -f $ConfigFile logs
        docker-compose -f $ConfigFile down
        return $false
    }

    # Test API
    $testResult = Test-Api $ConfigName
    if ($testResult) {
        Write-Log "$ConfigName test passed" "SUCCESS"
    } else {
        Write-Log "$ConfigName test failed" "ERROR"
    }

    # Quick container status check (skip detailed stats for speed)
    if ($testResult) {
        Write-Log "$ConfigName container running normally" "INFO"
    }

    # Stop service immediately
    Write-Log "Stopping $ConfigName service..." "INFO"
    docker-compose -f $ConfigFile down --timeout 10  # Quick shutdown

    return $testResult
}

# Main test process
function Main {
    Write-Host "Starting Docker configuration comprehensive test" -ForegroundColor $Colors.Green
    Write-Host "Test time: $(Get-Date)" -ForegroundColor $Colors.Blue
    Write-Host ""

    # Clean environment
    if (-not $SkipCleanup) {
        Invoke-Cleanup
    }

    # Define test configurations
    $configs = @{
        "docker-compose.yml" = "Standard Config"
        "docker-compose.low-spec.yml" = "Low Spec Config"
        "docker-compose.high-performance.yml" = "High Performance Config"
        "docker-compose.ultra-performance.yml" = "Ultra Performance Config"
        "docker-compose.prod.yml" = "Production Config"
    }

    $totalTests = 0
    $passedTests = 0
    $failedConfigs = @()

    # Test each configuration
    foreach ($configFile in $configs.Keys) {
        if (Test-Path $configFile) {
            $totalTests++

            if (Test-Config $configFile $configs[$configFile]) {
                $passedTests++
            } else {
                $failedConfigs += $configs[$configFile]
            }

            # Quick test interval
            Start-Sleep -Seconds 2  # Reduced from 5 seconds
        } else {
            Write-Log "Configuration file $configFile does not exist, skipping test" "WARNING"
        }
    }

    # Final cleanup
    if (-not $SkipCleanup) {
        Invoke-Cleanup
    }

    # Test results summary
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor $Colors.White
    Write-Host "Test Results Summary" -ForegroundColor $Colors.Green
    Write-Host "==========================================" -ForegroundColor $Colors.White
    Write-Host "Total tests: $totalTests"
    Write-Host "Passed tests: $passedTests"
    Write-Host "Failed tests: $($totalTests - $passedTests)"

    if ($failedConfigs.Count -eq 0) {
        Write-Log "All configuration tests passed!" "SUCCESS"
        Write-Host ""
        Write-Host "Tested configurations:"
        foreach ($configFile in $configs.Keys) {
            if (Test-Path $configFile) {
                Write-Host "  ✅ $($configs[$configFile]) ($configFile)" -ForegroundColor $Colors.Green
            }
        }

        Write-Host ""
        Write-Host "Generated test files:"
        $testFiles = Get-ChildItem -Path "." -Name "test_*.png"
        if ($testFiles) {
            foreach ($file in $testFiles) {
                $size = [math]::Round((Get-Item $file).Length / 1KB, 2)
                Write-Host "  📄 $file (${size}KB)" -ForegroundColor $Colors.Blue
            }
        } else {
            Write-Host "  (No test files generated)"
        }

        exit 0
    } else {
        Write-Log "Some configuration tests failed" "ERROR"
        Write-Host ""
        Write-Host "Failed configurations:"
        foreach ($config in $failedConfigs) {
            Write-Host "  ❌ $config" -ForegroundColor $Colors.Red
        }
        exit 1
    }
}

# Execute main process
try {
    Main
} catch {
    Write-Log "Error occurred during testing: $($_.Exception.Message)" "ERROR"
    if (-not $SkipCleanup) {
        Invoke-Cleanup
    }
    exit 1
}
