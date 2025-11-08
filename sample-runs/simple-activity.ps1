# Simple IBM MQ Activity Generator
# Parameters
$MessageCount = 15
$QueueManager = "MQQM1"
$Channel = "APP1.SVRCONN"
$ConnName = "127.0.0.1(5200)"
$Queues = @("APP1.REQ", "APP2.REQ")

Write-Host "=== IBM MQ Test Activity Generator ==="
Write-Host "Queue Manager: $QueueManager"
Write-Host "Connection: $ConnName via $Channel"
Write-Host "Target Queues: $($Queues -join ', ')"
Write-Host "Messages per queue: $MessageCount"
Write-Host ""

# Set environment
$env:MQSERVER = "$Channel/TCP/$ConnName"

# Function to put messages
function PutMessages($QueueName, $Count, $QmgrName) {
    Write-Host "Putting $Count messages to $QueueName..."
    
    $messages = @()
    for ($i = 1; $i -le $Count; $i++) {
        $messages += "Test message $i to $QueueName at $(Get-Date)"
    }
    $messages += ""  # Terminate amqsput
    
    try {
        $messages | & "C:\Program Files\IBM\MQ\bin64\amqsput.exe" $QueueName $QmgrName
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Put $Count messages successfully"
        } else {
            Write-Host "  ✗ Failed with exit code $LASTEXITCODE"
        }
    } catch {
        Write-Host "  ✗ Error: $_"
    }
}

# Function to get messages
function GetMessages($QueueName, $QmgrName) {
    Write-Host "Getting messages from $QueueName..."
    
    try {
        $result = & "C:\Program Files\IBM\MQ\bin64\amqsget.exe" $QueueName $QmgrName 2>&1
        $count = ($result | Measure-Object).Count
        Write-Host "  ✓ Retrieved $count messages"
    } catch {
        Write-Host "  ✗ Error: $_"
    }
}

# Function to check queue depth
function CheckQueue($QueueName, $QmgrName) {
    $script = "DIS QUEUE('$QueueName') CURDEPTH"
    $output = $script | runmqsc $QmgrName 2>&1
    $depth = "unknown"
    if ($output -match "CURDEPTH\((\d+)\)") {
        $depth = $matches[1]
    }
    Write-Host "  $QueueName : $depth messages"
}

# Main execution
Write-Host "Initial queue status:"
foreach ($q in $Queues) { CheckQueue $q $QueueManager }
Write-Host ""

foreach ($q in $Queues) {
    PutMessages $q $MessageCount $QueueManager
}
Write-Host ""

Write-Host "Queue status after puts:"
foreach ($q in $Queues) { CheckQueue $q $QueueManager }
Write-Host ""

$getCount = [Math]::Floor($MessageCount / 2)
foreach ($q in $Queues) {
    GetMessages $q $QueueManager
}
Write-Host ""

Write-Host "Final queue status:"
foreach ($q in $Queues) { CheckQueue $q $QueueManager }

Write-Host ""
Write-Host "=== Activity Generation Complete ==="
Write-Host "Statistics should now be available in:"
Write-Host "- SYSTEM.ADMIN.STATISTICS.QUEUE"
Write-Host "- SYSTEM.ADMIN.ACCOUNTING.QUEUE"