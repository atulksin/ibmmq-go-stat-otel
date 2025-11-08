# IBM MQ Statistics Collector - Readers and Writers Testing

This document demonstrates the IBM MQ Statistics and Accounting Collector's ability to identify and track applications that read from (consumers) and write to (producers) IBM MQ queues.

## Test Environment

- **Queue Manager**: MQQM1
- **Host**: 127.0.0.1:5200
- **Test Date**: November 8, 2025
- **IBM MQ Version**: 9.3.x
- **Collector Version**: dev

## Key Features Being Tested

### 1. Reader/Writer Identification
The collector analyzes PCF (Programmable Command Format) messages from IBM MQ accounting data to identify:

- **Readers (ipprocs)**: Applications that consume messages from queues (GET operations)
- **Writers (opprocs)**: Applications that produce messages to queues (PUT operations)
- **Application Names**: Identifies specific applications by name
- **Queue Usage Patterns**: Tracks which queues are being read from vs written to

### 2. Metrics Exposed
The collector exposes Prometheus metrics with the `ibmmq` prefix including:

- `ibmmq_queue_has_readers` - Boolean metric (1=has readers, 0=no readers)
- `ibmmq_queue_has_writers` - Boolean metric (1=has writers, 0=no writers)
- `ibmmq_app_get_count` - Number of GET operations by application
- `ibmmq_app_put_count` - Number of PUT operations by application
- `ibmmq_queue_input_handles` - Number of input handles (readers)
- `ibmmq_queue_output_handles` - Number of output handles (writers)

## Test Execution

### Test 1: Basic Connection and Data Collection

```bash
# Build the collector
go build -o ibmmq-collector.exe ./cmd/collector

# Run one-time collection with debug logging
./ibmmq-collector.exe --mq-host 127.0.0.1 --mq-port 5200 --mq-queue-manager MQQM1 --log-level debug --once
```

### Test 2: PCF Message Analysis

```bash
# Build and run the PCF dumper to show raw data structure
go build -o pcf-dumper.exe ./cmd/pcf-dumper

# Dump accounting messages to see reader/writer data
./pcf-dumper.exe --queue-manager MQQM1 --host 127.0.0.1 --port 5200 --queue SYSTEM.ADMIN.ACCOUNTING.QUEUE --count 10
```

### Test 3: Continuous Monitoring with Metrics

```bash
# Start collector in continuous mode
./ibmmq-collector.exe --mq-host 127.0.0.1 --mq-port 5200 --mq-queue-manager MQQM1 --interval 30s --metrics-port 9090

# In another terminal, check metrics
curl http://localhost:9090/metrics | grep ibmmq
```

## Expected Output Patterns

### 1. PCF Data Structure (from accounting messages)
When analyzing IBM MQ accounting data, we should see parameters like:

```
Parameter ID: 2001 (MQIA_APPL_TYPE), Value: 11 (Application Type)
Parameter ID: 2005 (MQCA_APPL_NAME), Value: "MQ Explorer" (Application Name)  
Parameter ID: 2028 (MQIA_OPEN_INPUT_COUNT), Value: 5 (Input/Reader operations)
Parameter ID: 2029 (MQIA_OPEN_OUTPUT_COUNT), Value: 0 (Output/Writer operations)
Parameter ID: 2030 (MQIA_GET_COUNT), Value: 142 (GET operations - readers)
Parameter ID: 2031 (MQIA_PUT_COUNT), Value: 0 (PUT operations - writers)
```

### 2. Prometheus Metrics Output
Expected metrics showing reader/writer activity:

```
# HELP ibmmq_queue_has_readers Whether the queue has active readers (1=yes, 0=no)
# TYPE ibmmq_queue_has_readers gauge
ibmmq_queue_has_readers{queue_manager="MQQM1",queue="SYSTEM.ADMIN.ACCOUNTING.QUEUE"} 1

# HELP ibmmq_queue_has_writers Whether the queue has active writers (1=yes, 0=no)  
# TYPE ibmmq_queue_has_writers gauge
ibmmq_queue_has_writers{queue_manager="MQQM1",queue="SYSTEM.ADMIN.ACCOUNTING.QUEUE"} 0

# HELP ibmmq_app_get_count Total GET operations by application
# TYPE ibmmq_app_get_count counter
ibmmq_app_get_count{queue_manager="MQQM1",application="MQ Explorer",queue="SYSTEM.ADMIN.ACCOUNTING.QUEUE"} 142

# HELP ibmmq_app_put_count Total PUT operations by application  
# TYPE ibmmq_app_put_count counter
ibmmq_app_put_count{queue_manager="MQQM1",application="IBM MQ Client",queue="SYSTEM.DEFAULT.LOCAL.QUEUE"} 25
```

### 3. Application Activity Summary
The collector should identify and report:

- **Reader Applications**: MQ Explorer, monitoring tools, consumer applications
- **Writer Applications**: Producer applications, IBM MQ clients, administrative tools
- **Queue Activity**: Which queues are actively being read from vs written to
- **Operation Counts**: Detailed statistics on GET/PUT operations per application

## Test Configuration

### Configuration File (test-config.yaml)
```yaml
mq:
  queue_manager: "MQQM1"
  host: "127.0.0.1"
  port: 5200
  channel: "SYSTEM.DEF.SVRCONN"
  
collector:
  interval: "30s"
  statistics_queue: "SYSTEM.ADMIN.STATISTICS.QUEUE"
  accounting_queue: "SYSTEM.ADMIN.ACCOUNTING.QUEUE"
  timeout: "10s"
  max_messages: 100

metrics:
  enabled: true
  address: "0.0.0.0:9090"
  path: "/metrics"
  namespace: "ibmmq"

logging:
  level: "debug"
  format: "json"
```

## Validation Checklist

- [ ] Successfully connects to IBM MQ MQQM1
- [ ] Retrieves accounting messages from SYSTEM.ADMIN.ACCOUNTING.QUEUE
- [ ] Parses PCF parameters correctly (62+ parameters per message)
- [ ] Identifies reader applications (ipprocs > 0)
- [ ] Identifies writer applications (opprocs > 0)  
- [ ] Exposes reader/writer metrics via Prometheus
- [ ] Shows application names and operation counts
- [ ] Differentiates between queue types (statistics vs accounting)
- [ ] Handles multiple applications per queue
- [ ] Updates metrics in real-time during continuous monitoring

## Expected Behavior

### Reader Detection
- Applications performing GET operations will show up with ipprocs > 0
- Metrics `ibmmq_queue_has_readers=1` for queues with active consumers
- Individual application metrics showing GET counts

### Writer Detection  
- Applications performing PUT operations will show up with opprocs > 0
- Metrics `ibmmq_queue_has_writers=1` for queues with active producers
- Individual application metrics showing PUT counts

### Real-time Updates
- Metrics should update as new accounting messages arrive
- Reader/writer status should reflect current activity
- Historical data should accumulate in counter metrics

This test framework validates that the IBM MQ Statistics Collector successfully identifies and reports on applications that read from and write to IBM MQ queues, providing valuable insights for queue management and application monitoring.