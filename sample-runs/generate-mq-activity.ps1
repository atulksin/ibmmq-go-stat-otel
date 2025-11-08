param(
    [int]$MessageCount = 10,
    [string]$QueueManager = "MQQM1",
    [string]$Channel = "APP1.SVRCONN",
    [string]$ConnName = "127.0.0.1(5200)",
    [string[]]$Queues = @("APP1.REQ", "APP2.REQ")
)

Write-Host "Generating IBM MQ test activity..."
Write-Host "Queue Manager: $QueueManager"
Write-Host "Channel: $Channel"  
Write-Host "Connection: $ConnName"
Write-Host "Queues: $($Queues -join ', ')"
Write-Host "Messages per queue: $MessageCount"
Write-Host ""

# Set IBM MQ environment variables
$env:MQSERVER = "$Channel/TCP/$ConnName"

function Put-Messages {
    param([string]$QueueName, [int]$Count, [string]$QmgrName)
    
    Write-Host "Putting $Count messages to queue $QueueName..."
    
    $messages = @()
    for ($i = 1; $i -le $Count; $i++) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $messages += "Test message $i for $QueueName - Generated at $timestamp"
    }
    $messages += ""  # Empty line to terminate amqsput
    
    try {
        $messages | & "C:\Program Files\IBM\MQ\bin64\amqsput.exe" $QueueName $QmgrName
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Successfully put $Count messages to $QueueName"
        } else {
            Write-Host "✗ Failed to put messages to $QueueName (Exit code: $LASTEXITCODE)"
        }
    } catch {
        Write-Host "✗ Error putting messages to $QueueName : $_"
    }
    Write-Host ""
}

function Get-Messages {
    param([string]$QueueName, [int]$Count, [string]$QmgrName)
    
    Write-Host "Getting up to $Count messages from queue $QueueName..."
    
    try {
        $output = & "C:\Program Files\IBM\MQ\bin64\amqsget.exe" $QueueName $QmgrName 2>&1
        if ($LASTEXITCODE -eq 0) {
            $messageCount = ($output | Measure-Object).Count
            Write-Host "✓ Successfully got $messageCount messages from $QueueName"
            if ($messageCount -gt 0) {
                Write-Host "Sample messages:"
                $output | Select-Object -First 3 | ForEach-Object { Write-Host "  - $_" }
                if ($messageCount -gt 3) {
                    Write-Host "  ... and $($messageCount - 3) more"
                }
            }
        } else {
            Write-Host "✓ No messages available in $QueueName or queue empty"
        }
    } catch {
        Write-Host "✗ Error getting messages from $QueueName : $_"
    }
    Write-Host ""
}

function Check-QueueStatus {
    param([string[]]$QueueNames, [string]$QmgrName)
    
    Write-Host "Checking queue status..."
    
    foreach ($queue in $QueueNames) {
        try {
            $mqscScript = "DIS QUEUE('$queue') CURDEPTH MAXDEPTH"
            $output = $mqscScript | & runmqsc $QmgrName 2>&1
            
            $depthPattern = 'CURDEPTH\((\d+)\)'
            $depthLine = $output | Where-Object { $_ -match $depthPattern }
            if ($depthLine -and $depthLine -match $depthPattern) {
                $currentDepth = $matches[1]
                Write-Host "  $queue : $currentDepth messages"
            } else {
                Write-Host "  $queue : Status unknown"
            }
        } catch {
            Write-Host "  $queue : Error checking status"
        }
    }
    Write-Host ""
}

# Main execution
Write-Host "=== Starting Test Activity Generation ===" -ForegroundColor Green

Check-QueueStatus -QueueNames $Queues -QmgrName $QueueManager

foreach ($queue in $Queues) {
    Put-Messages -QueueName $queue -Count $MessageCount -QmgrName $QueueManager
}

Write-Host "Queue status after putting messages:"
Check-QueueStatus -QueueNames $Queues -QmgrName $QueueManager

$getCount = [math]::Max(1, [math]::Floor($MessageCount / 2))
foreach ($queue in $Queues) {
    Get-Messages -QueueName $queue -Count $getCount -QmgrName $QueueManager
}

Write-Host "Final queue status:"
Check-QueueStatus -QueueNames $Queues -QmgrName $QueueManager

Write-Host "=== Test Activity Generation Complete ===" -ForegroundColor Green
Write-Host "This activity should have generated statistics and accounting data."
Write-Host "You can now run the IBM MQ collector to gather metrics from:"
Write-Host "  - SYSTEM.ADMIN.STATISTICS.QUEUE"
Write-Host "  - SYSTEM.ADMIN.ACCOUNTING.QUEUE"