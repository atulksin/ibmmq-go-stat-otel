# Simple IBM MQ Test Activity
$env:MQSERVER = "APP1.SVRCONN/TCP/127.0.0.1(5200)"

Write-Host "=== IBM MQ Activity Test ==="
Write-Host "Checking initial queue status..."

# Check APP1.REQ
"DIS QUEUE('APP1.REQ') CURDEPTH" | runmqsc MQQM1

# Check APP2.REQ  
"DIS QUEUE('APP2.REQ') CURDEPTH" | runmqsc MQQM1

Write-Host ""
Write-Host "Putting test messages..."

# Put messages to APP1.REQ
@(
    "Test message 1 to APP1.REQ"
    "Test message 2 to APP1.REQ" 
    "Test message 3 to APP1.REQ"
    "Test message 4 to APP1.REQ"
    "Test message 5 to APP1.REQ"
    ""
) | & "C:\Program Files\IBM\MQ\bin64\amqsput.exe" APP1.REQ MQQM1

# Put messages to APP2.REQ
@(
    "Test message 1 to APP2.REQ"
    "Test message 2 to APP2.REQ"
    "Test message 3 to APP2.REQ"
    ""
) | & "C:\Program Files\IBM\MQ\bin64\amqsput.exe" APP2.REQ MQQM1

Write-Host "Messages put. Checking queue status..."

# Check queues after putting
"DIS QUEUE('APP1.REQ') CURDEPTH" | runmqsc MQQM1
"DIS QUEUE('APP2.REQ') CURDEPTH" | runmqsc MQQM1

Write-Host ""
Write-Host "Getting some messages back..."

# Get messages from APP1.REQ
& "C:\Program Files\IBM\MQ\bin64\amqsget.exe" APP1.REQ MQQM1

Write-Host ""
Write-Host "Final queue status:"
"DIS QUEUE('APP1.REQ') CURDEPTH" | runmqsc MQQM1  
"DIS QUEUE('APP2.REQ') CURDEPTH" | runmqsc MQQM1

Write-Host ""
Write-Host "Activity complete! Check statistics queues for data."