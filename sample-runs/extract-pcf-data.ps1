# PCF Data Extractor using IBM MQ samples
# This script reads messages from statistics and accounting queues and saves them as binary files

param(
    [string]$QueueManager = "MQQM1",
    [string]$Channel = "APP1.SVRCONN", 
    [string]$ConnName = "127.0.0.1(5200)"
)

Write-Host "=== PCF Data Extractor ==="
Write-Host "Extracting raw PCF data from IBM MQ admin queues..."
Write-Host "Queue Manager: $QueueManager"
Write-Host "Connection: $ConnName via $Channel"
Write-Host ""

# Set environment
$env:MQSERVER = "$Channel/TCP/$ConnName"

# Create output directory
$outputDir = "sample-runs\pcf-data"
if (!(Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

Write-Host "Checking statistics queue..."
$statsScript = "DIS QUEUE('SYSTEM.ADMIN.STATISTICS.QUEUE') CURDEPTH"
$statsOutput = $statsScript | runmqsc $QueueManager 2>&1
if ($statsOutput -match "CURDEPTH\((\d+)\)") {
    $statsCount = $matches[1]
    Write-Host "  Statistics messages available: $statsCount"
}

Write-Host "Checking accounting queue..."
$acctScript = "DIS QUEUE('SYSTEM.ADMIN.ACCOUNTING.QUEUE') CURDEPTH"  
$acctOutput = $acctScript | runmqsc $QueueManager 2>&1
if ($acctOutput -match "CURDEPTH\((\d+)\)") {
    $acctCount = $matches[1]
    Write-Host "  Accounting messages available: $acctCount"
}

Write-Host ""
Write-Host "Note: IBM MQ sample programs (amqsget) retrieve messages as text."
Write-Host "For actual PCF binary data extraction, we need:"
Write-Host "1. A compiled Go program with IBM MQ client library"
Write-Host "2. Or a custom C program using IBM MQ API"
Write-Host ""

# For now, let's get the text representation to analyze structure
Write-Host "Getting text representation of statistics messages..."
try {
    $statsMessages = & "C:\Program Files\IBM\MQ\bin64\amqsget.exe" SYSTEM.ADMIN.STATISTICS.QUEUE $QueueManager 2>&1
    if ($statsMessages) {
        $statsMessages | Out-File -FilePath "$outputDir\statistics-messages.txt" -Encoding UTF8
        Write-Host "  ✓ Statistics messages saved to: $outputDir\statistics-messages.txt"
        Write-Host "  Sample content:"
        $statsMessages | Select-Object -First 5 | ForEach-Object { Write-Host "    $_" }
    }
} catch {
    Write-Host "  ✗ Error reading statistics: $_"
}

Write-Host ""
Write-Host "Getting text representation of accounting messages..."
try {
    $acctMessages = & "C:\Program Files\IBM\MQ\bin64\amqsget.exe" SYSTEM.ADMIN.ACCOUNTING.QUEUE $QueueManager 2>&1  
    if ($acctMessages) {
        $acctMessages | Out-File -FilePath "$outputDir\accounting-messages.txt" -Encoding UTF8
        Write-Host "  ✓ Accounting messages saved to: $outputDir\accounting-messages.txt"
        Write-Host "  Sample content:"
        $acctMessages | Select-Object -First 5 | ForEach-Object { Write-Host "    $_" }
    }
} catch {
    Write-Host "  ✗ Error reading accounting: $_"
}

Write-Host ""
Write-Host "=== PCF Data Extraction Summary ==="
Write-Host "Text representations saved. To get binary PCF data we need:"
Write-Host "1. Resolve CGO build issues, OR"
Write-Host "2. Use Docker with proper build environment, OR" 
Write-Host "3. Create custom C program for PCF extraction"