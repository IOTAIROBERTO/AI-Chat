# VR Training AI Server - Diagnostic Script
# Run this to check if everything is configured correctly

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  VR TRAINING AI SERVER - SYSTEM DIAGNOSTICS" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Python Version
Write-Host "[1/6] Checking Python..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version 2>&1
    if ($pythonVersion -match "Python 3\.1[1-9]" -or $pythonVersion -match "Python 3\.[2-9]") {
        Write-Host "   [OK] $pythonVersion" -ForegroundColor Green
    } else {
        Write-Host "   [WARNING] $pythonVersion (3.11+ recommended)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   [ERROR] Python not found in PATH" -ForegroundColor Red
    Write-Host "   Install from: https://www.python.org/downloads/" -ForegroundColor Yellow
}

Write-Host ""

# Test 2: Ollama Status
Write-Host "[2/6] Checking Ollama..." -ForegroundColor Yellow
$ollamaProcess = Get-Process ollama -ErrorAction SilentlyContinue

if ($ollamaProcess) {
    Write-Host "   [OK] Ollama is running (PID: $($ollamaProcess.Id))" -ForegroundColor Green
    
    try {
        Write-Host "   Available models:" -ForegroundColor Cyan
        ollama list | ForEach-Object {
            Write-Host "      $_" -ForegroundColor Gray
        }
    } catch {
        Write-Host "   [WARNING] Could not list models" -ForegroundColor Yellow
    }
} else {
    Write-Host "   [ERROR] Ollama is NOT running" -ForegroundColor Red
    Write-Host "   Start it with: ollama serve" -ForegroundColor Yellow
    Write-Host "   Download from: https://ollama.com/download" -ForegroundColor Yellow
}

Write-Host ""

# Test 3: Port 5000 Availability
Write-Host "[3/6] Checking Port 5000..." -ForegroundColor Yellow
$portInUse = netstat -ano | Select-String ":5000.*LISTENING"

if ($portInUse) {
    Write-Host "   [WARNING] Port 5000 is already in use:" -ForegroundColor Yellow
    $portInUse | ForEach-Object {
        Write-Host "      $_" -ForegroundColor Gray
    }
    Write-Host "   Close the application using it or change SERVER_PORT in offline_server.py" -ForegroundColor Yellow
} else {
    Write-Host "   [OK] Port 5000 is available" -ForegroundColor Green
}

Write-Host ""

# Test 4: Python Dependencies
Write-Host "[4/6] Checking Python Dependencies..." -ForegroundColor Yellow
$requiredPackages = @(
    @{Name="flask"; Display="Flask (web server)"},
    @{Name="flask-cors"; Display="Flask-CORS (web server)"},
    @{Name="chromadb"; Display="ChromaDB (vector database)"},
    @{Name="ollama"; Display="Ollama Python client"},
    @{Name="faster-whisper"; Display="Faster-Whisper (voice)"},
    @{Name="pypdf"; Display="PyPDF (PDF parsing)"},
    @{Name="requests"; Display="Requests (HTTP client)"}
)

$missingPackages = @()
foreach ($pkg in $requiredPackages) {
    $installed = pip list 2>$null | Select-String -Pattern "^$($pkg.Name)\s" -Quiet
    if ($installed) {
        Write-Host "   [OK] $($pkg.Display)" -ForegroundColor Green
    } else {
        Write-Host "   [ERROR] $($pkg.Display) - NOT INSTALLED" -ForegroundColor Red
        $missingPackages += $pkg.Name
    }
}

if ($missingPackages.Count -gt 0) {
    Write-Host ""
    Write-Host "   Install missing packages with:" -ForegroundColor Yellow
    Write-Host "   pip install $($missingPackages -join ' ')" -ForegroundColor Cyan
}

Write-Host ""

# Test 5: Server Files
Write-Host "[5/6] Checking Server Files..." -ForegroundColor Yellow
$currentDir = Get-Location
$serverFiles = @(
    "offline_server.py",
    "launcher.py"
)

foreach ($file in $serverFiles) {
    $filePath = Join-Path $currentDir $file
    if (Test-Path $filePath) {
        Write-Host "   [OK] $file found" -ForegroundColor Green
    } else {
        Write-Host "   [ERROR] $file NOT FOUND in current directory" -ForegroundColor Red
    }
}

Write-Host ""

# Test 6: Network Connectivity
Write-Host "[6/6] Checking Network..." -ForegroundColor Yellow
try {
    $testConnection = Test-Connection -ComputerName localhost -Count 1 -Quiet
    if ($testConnection) {
        Write-Host "   [OK] Localhost is reachable" -ForegroundColor Green
    } else {
        Write-Host "   [WARNING] Cannot reach localhost" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   [WARNING] Network test failed" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  SUMMARY" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Generate summary
$pythonOk = (python --version 2>&1) -match "Python"
$ollamaOk = $ollamaProcess -ne $null
$portOk = -not $portInUse
$depsOk = $missingPackages.Count -eq 0
$filesOk = (Test-Path "offline_server.py") -and (Test-Path "launcher.py")

if ($pythonOk -and $ollamaOk -and $portOk -and $depsOk -and $filesOk) {
    Write-Host "STATUS: [READY TO RUN]" -ForegroundColor Green
    Write-Host ""
    Write-Host "Everything looks good! You can now:" -ForegroundColor Green
    Write-Host "1. Run: python launcher.py" -ForegroundColor Cyan
    Write-Host "2. Click 'Start Server'" -ForegroundColor Cyan
    Write-Host "3. Wait for connection (up to 30 seconds)" -ForegroundColor Cyan
} elseif (-not $ollamaOk) {
    Write-Host "STATUS: [OLLAMA NOT RUNNING]" -ForegroundColor Red
    Write-Host ""
    Write-Host "CRITICAL: Start Ollama first!" -ForegroundColor Red
    Write-Host "1. Open a new terminal" -ForegroundColor Cyan
    Write-Host "2. Run: ollama serve" -ForegroundColor Cyan
    Write-Host "3. Wait for 'Ollama is running'" -ForegroundColor Cyan
    Write-Host "4. Then start the launcher" -ForegroundColor Cyan
} elseif (-not $depsOk) {
    Write-Host "STATUS: [MISSING DEPENDENCIES]" -ForegroundColor Red
    Write-Host ""
    Write-Host "Install missing packages:" -ForegroundColor Yellow
    Write-Host "pip install $($missingPackages -join ' ')" -ForegroundColor Cyan
} elseif (-not $portOk) {
    Write-Host "STATUS: [PORT CONFLICT]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Port 5000 is in use. Options:" -ForegroundColor Yellow
    Write-Host "1. Close the app using port 5000" -ForegroundColor Cyan
    Write-Host "2. Or edit SERVER_PORT in offline_server.py" -ForegroundColor Cyan
} else {
    Write-Host "STATUS: [NEEDS ATTENTION]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Review the errors above and fix them." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Pause at the end
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
