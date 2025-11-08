package pcf

import (
	"encoding/binary"
	"fmt"
	"time"

	"github.com/sirupsen/logrus"
)

// PCF Parameter Types
const (
	MQCFT_NONE               = 0x00000000
	MQCFT_COMMAND            = 0x00000001
	MQCFT_RESPONSE           = 0x00000002
	MQCFT_INTEGER            = 0x00000003
	MQCFT_STRING             = 0x00000004
	MQCFT_INTEGER_LIST       = 0x00000005
	MQCFT_STRING_LIST        = 0x00000006
	MQCFT_EVENT              = 0x00000007
	MQCFT_USER               = 0x00000008
	MQCFT_BYTE_STRING        = 0x00000009
	MQCFT_TRACE_ROUTE        = 0x0000000A
	MQCFT_REPORT             = 0x0000000B
	MQCFT_INTEGER_FILTER     = 0x0000000C
	MQCFT_STRING_FILTER      = 0x0000000D
	MQCFT_BYTE_STRING_FILTER = 0x0000000E
	MQCFT_COMMAND_XR         = 0x0000000F
	MQCFT_XR_MSG             = 0x00000010
	MQCFT_XR_ITEM            = 0x00000011
	MQCFT_XR_SUMMARY         = 0x00000012
	MQCFT_GROUP              = 0x00000013
	MQCFT_STATISTICS         = 0x00000014
	MQCFT_ACCOUNTING         = 0x00000015
)

// Common IBM MQ Constants
const (
	// Statistics Types
	MQCMD_STATISTICS_MQI     = 0x00000070
	MQCMD_STATISTICS_Q       = 0x00000071
	MQCMD_STATISTICS_CHANNEL = 0x00000072

	// Accounting Types
	MQCMD_ACCOUNTING_MQI = 0x0000008A
	MQCMD_ACCOUNTING_Q   = 0x0000008B

	// Common Parameters
	MQCA_Q_NAME            = 2016
	MQCA_Q_MGR_NAME        = 2002
	MQCA_CHANNEL_NAME      = 3501
	MQCA_CONNECTION_NAME   = 3502
	MQCA_APPL_NAME         = 2024
	MQIA_Q_TYPE            = 20
	MQIA_CURRENT_Q_DEPTH   = 3
	MQIA_OPEN_INPUT_COUNT  = 65
	MQIA_OPEN_OUTPUT_COUNT = 66

	// Queue Statistics
	MQIA_HIGH_Q_DEPTH  = 36
	MQIA_MSG_DEQ_COUNT = 38 // Messages dequeued (GET count)
	MQIA_MSG_ENQ_COUNT = 37 // Messages enqueued (PUT count)

	// Channel Statistics
	MQIACH_MSGS    = 1501
	MQIACH_BYTES   = 1502
	MQIACH_BATCHES = 1503

	// MQI Statistics
	MQIAMO_OPENS    = 3
	MQIAMO_CLOSES   = 4
	MQIAMO_PUTS     = 17
	MQIAMO_GETS     = 18
	MQIAMO_COMMITS  = 12
	MQIAMO_BACKOUTS = 13

	// Time parameters
	MQCACF_COMMAND_TIME    = 3603
	MQIACF_SEQUENCE_NUMBER = 1001
)

// PCFHeader represents the PCF message header
type PCFHeader struct {
	Type           int32
	StrucLength    int32
	Version        int32
	Command        int32
	MsgSeqNumber   int32
	Control        int32
	CompCode       int32
	Reason         int32
	ParameterCount int32
}

// PCFParameter represents a PCF parameter
type PCFParameter struct {
	Parameter int32
	Type      int32
	Length    int32
	Value     interface{}
}

// StatisticsData represents parsed statistics data
type StatisticsData struct {
	Type         string                 `json:"type"`
	QueueManager string                 `json:"queue_manager"`
	Timestamp    time.Time              `json:"timestamp"`
	Parameters   map[string]interface{} `json:"parameters"`
	QueueStats   *QueueStatistics       `json:"queue_stats,omitempty"`
	ChannelStats *ChannelStatistics     `json:"channel_stats,omitempty"`
	MQIStats     *MQIStatistics         `json:"mqi_stats,omitempty"`
}

// QueueStatistics represents queue-specific statistics
type QueueStatistics struct {
	QueueName    string `json:"queue_name"`
	CurrentDepth int32  `json:"current_depth"`
	HighDepth    int32  `json:"high_depth"`
	InputCount   int32  `json:"input_count"`
	OutputCount  int32  `json:"output_count"`
	EnqueueCount int32  `json:"enqueue_count"`
	DequeueCount int32  `json:"dequeue_count"`
	HasReaders   bool   `json:"has_readers"`
	HasWriters   bool   `json:"has_writers"`
}

// ChannelStatistics represents channel-specific statistics
type ChannelStatistics struct {
	ChannelName    string `json:"channel_name"`
	ConnectionName string `json:"connection_name"`
	Messages       int32  `json:"messages"`
	Bytes          int64  `json:"bytes"`
	Batches        int32  `json:"batches"`
}

// MQIStatistics represents MQI-specific statistics
type MQIStatistics struct {
	ApplicationName string `json:"application_name"`
	Opens           int32  `json:"opens"`
	Closes          int32  `json:"closes"`
	Puts            int32  `json:"puts"`
	Gets            int32  `json:"gets"`
	Commits         int32  `json:"commits"`
	Backouts        int32  `json:"backouts"`
}

// AccountingData represents parsed accounting data
type AccountingData struct {
	Type           string                 `json:"type"`
	QueueManager   string                 `json:"queue_manager"`
	Timestamp      time.Time              `json:"timestamp"`
	Parameters     map[string]interface{} `json:"parameters"`
	ConnectionInfo *ConnectionInfo        `json:"connection_info,omitempty"`
	Operations     *OperationCounts       `json:"operations,omitempty"`
}

// ConnectionInfo represents connection-specific accounting data
type ConnectionInfo struct {
	ChannelName     string    `json:"channel_name"`
	ConnectionName  string    `json:"connection_name"`
	ApplicationName string    `json:"application_name"`
	ConnectTime     time.Time `json:"connect_time"`
	DisconnectTime  time.Time `json:"disconnect_time"`
}

// OperationCounts represents operation counts from accounting data
type OperationCounts struct {
	Gets     int32 `json:"gets"`
	Puts     int32 `json:"puts"`
	Browses  int32 `json:"browses"`
	Opens    int32 `json:"opens"`
	Closes   int32 `json:"closes"`
	Commits  int32 `json:"commits"`
	Backouts int32 `json:"backouts"`
}

// Parser handles PCF message parsing
type Parser struct {
	logger *logrus.Logger
}

// NewParser creates a new PCF parser instance
func NewParser(logger *logrus.Logger) *Parser {
	return &Parser{
		logger: logger,
	}
}

// ParseMessage parses a PCF message and returns structured data
func (p *Parser) ParseMessage(data []byte, msgType string) (interface{}, error) {
	if len(data) < 36 { // Minimum PCF header size
		return nil, fmt.Errorf("message too short to be a valid PCF message")
	}

	header, err := p.parseHeader(data)
	if err != nil {
		return nil, fmt.Errorf("failed to parse PCF header: %w", err)
	}

	p.logger.WithFields(logrus.Fields{
		"command":         header.Command,
		"type":            header.Type,
		"parameter_count": header.ParameterCount,
		"message_type":    msgType,
	}).Debug("Parsing PCF message")

	parameters, err := p.parseParameters(data[36:], header.ParameterCount)
	if err != nil {
		return nil, fmt.Errorf("failed to parse PCF parameters: %w", err)
	}

	// Determine if this is statistics or accounting data based on command
	switch {
	case header.Command == MQCMD_STATISTICS_Q || header.Command == MQCMD_STATISTICS_CHANNEL || header.Command == MQCMD_STATISTICS_MQI:
		return p.parseStatistics(header, parameters)
	case header.Command == MQCMD_ACCOUNTING_Q || header.Command == MQCMD_ACCOUNTING_MQI:
		return p.parseAccounting(header, parameters)
	default:
		// Generic parsing for other message types
		return &StatisticsData{
			Type:       msgType,
			Timestamp:  time.Now(),
			Parameters: p.convertParameters(parameters),
		}, nil
	}
}

// parseHeader parses the PCF header
func (p *Parser) parseHeader(data []byte) (*PCFHeader, error) {
	if len(data) < 36 {
		return nil, fmt.Errorf("insufficient data for PCF header")
	}

	header := &PCFHeader{
		Type:           int32(binary.LittleEndian.Uint32(data[0:4])),
		StrucLength:    int32(binary.LittleEndian.Uint32(data[4:8])),
		Version:        int32(binary.LittleEndian.Uint32(data[8:12])),
		Command:        int32(binary.LittleEndian.Uint32(data[12:16])),
		MsgSeqNumber:   int32(binary.LittleEndian.Uint32(data[16:20])),
		Control:        int32(binary.LittleEndian.Uint32(data[20:24])),
		CompCode:       int32(binary.LittleEndian.Uint32(data[24:28])),
		Reason:         int32(binary.LittleEndian.Uint32(data[28:32])),
		ParameterCount: int32(binary.LittleEndian.Uint32(data[32:36])),
	}

	return header, nil
}

// parseParameters parses PCF parameters
func (p *Parser) parseParameters(data []byte, count int32) ([]*PCFParameter, error) {
	var parameters []*PCFParameter
	offset := 0

	for offset < len(data) {
		if offset+12 > len(data) {
			p.logger.WithField("remaining_bytes", len(data)-offset).Debug("Not enough bytes for PCF parameter header")
			break
		}

		param := &PCFParameter{
			Parameter: int32(binary.LittleEndian.Uint32(data[offset : offset+4])),
			Type:      int32(binary.LittleEndian.Uint32(data[offset+4 : offset+8])),
			Length:    int32(binary.LittleEndian.Uint32(data[offset+8 : offset+12])),
		}

		// Validate parameter length
		if param.Length < 12 || param.Length > 65536 {
			p.logger.WithFields(logrus.Fields{
				"parameter": param.Parameter,
				"type":      param.Type,
				"length":    param.Length,
				"offset":    offset,
			}).Warn("Invalid parameter length, skipping to next message")
			break
		}

		if offset+int(param.Length) > len(data) {
			p.logger.WithFields(logrus.Fields{
				"parameter":    param.Parameter,
				"length":       param.Length,
				"offset":       offset,
				"data_length":  len(data),
				"required_end": offset + int(param.Length),
			}).Warn("Parameter extends beyond data length")
			break
		}

		// Parse parameter value based on type
		switch param.Type {
		case MQCFT_INTEGER:
			if param.Length >= 16 {
				param.Value = int32(binary.LittleEndian.Uint32(data[offset+12 : offset+16]))
			}
		case MQCFT_STRING:
			if param.Length > 12 {
				strLen := param.Length - 12
				str := string(data[offset+12 : offset+12+int(strLen)])
				// Remove null terminators and trim spaces
				param.Value = p.cleanString(str)
			}
		case MQCFT_BYTE_STRING:
			if param.Length > 12 {
				dataLen := param.Length - 12
				param.Value = data[offset+12 : offset+12+int(dataLen)]
			}
		default:
			// Unknown parameter type, skip
			param.Value = nil
		}

		parameters = append(parameters, param)
		offset += int(param.Length)

		// Ensure 4-byte alignment
		if offset%4 != 0 {
			offset += 4 - (offset % 4)
		}
	}

	return parameters, nil
}

// parseStatistics converts parameters to statistics data structure
func (p *Parser) parseStatistics(header *PCFHeader, parameters []*PCFParameter) (*StatisticsData, error) {
	stats := &StatisticsData{
		Type:       "statistics",
		Timestamp:  time.Now(),
		Parameters: p.convertParameters(parameters),
	}

	// Extract common fields
	for _, param := range parameters {
		switch param.Parameter {
		case MQCA_Q_MGR_NAME:
			if str, ok := param.Value.(string); ok {
				stats.QueueManager = str
			}
		case MQCACF_COMMAND_TIME:
			// Parse MQ timestamp format if available
			if str, ok := param.Value.(string); ok {
				if t, err := p.parseMQTimestamp(str); err == nil {
					stats.Timestamp = t
				}
			}
		}
	}

	// Parse specific statistics based on command type
	switch header.Command {
	case MQCMD_STATISTICS_Q:
		stats.QueueStats = p.parseQueueStats(parameters)
	case MQCMD_STATISTICS_CHANNEL:
		stats.ChannelStats = p.parseChannelStats(parameters)
	case MQCMD_STATISTICS_MQI:
		stats.MQIStats = p.parseMQIStats(parameters)
	}

	return stats, nil
}

// parseAccounting converts parameters to accounting data structure
func (p *Parser) parseAccounting(header *PCFHeader, parameters []*PCFParameter) (*AccountingData, error) {
	acct := &AccountingData{
		Type:       "accounting",
		Timestamp:  time.Now(),
		Parameters: p.convertParameters(parameters),
	}

	// Extract common fields
	for _, param := range parameters {
		switch param.Parameter {
		case MQCA_Q_MGR_NAME:
			if str, ok := param.Value.(string); ok {
				acct.QueueManager = str
			}
		case MQCACF_COMMAND_TIME:
			if str, ok := param.Value.(string); ok {
				if t, err := p.parseMQTimestamp(str); err == nil {
					acct.Timestamp = t
				}
			}
		}
	}

	// Parse accounting-specific data
	acct.ConnectionInfo = p.parseConnectionInfo(parameters)
	acct.Operations = p.parseOperationCounts(parameters)

	return acct, nil
}

// parseQueueStats extracts queue statistics from parameters
func (p *Parser) parseQueueStats(parameters []*PCFParameter) *QueueStatistics {
	stats := &QueueStatistics{}

	for _, param := range parameters {
		if val, ok := param.Value.(int32); ok {
			switch param.Parameter {
			case MQIA_CURRENT_Q_DEPTH:
				stats.CurrentDepth = val
			case MQIA_HIGH_Q_DEPTH:
				stats.HighDepth = val
			case MQIA_OPEN_INPUT_COUNT:
				stats.InputCount = val
				stats.HasReaders = val > 0
			case MQIA_OPEN_OUTPUT_COUNT:
				stats.OutputCount = val
				stats.HasWriters = val > 0
			case MQIA_MSG_ENQ_COUNT:
				stats.EnqueueCount = val
			case MQIA_MSG_DEQ_COUNT:
				stats.DequeueCount = val
			}
		} else if str, ok := param.Value.(string); ok {
			switch param.Parameter {
			case MQCA_Q_NAME:
				stats.QueueName = str
			}
		}
	}

	return stats
}

// parseChannelStats extracts channel statistics from parameters
func (p *Parser) parseChannelStats(parameters []*PCFParameter) *ChannelStatistics {
	stats := &ChannelStatistics{}

	for _, param := range parameters {
		if val, ok := param.Value.(int32); ok {
			switch param.Parameter {
			case MQIACH_MSGS:
				stats.Messages = val
			case MQIACH_BYTES:
				stats.Bytes = int64(val)
			case MQIACH_BATCHES:
				stats.Batches = val
			}
		} else if str, ok := param.Value.(string); ok {
			switch param.Parameter {
			case MQCA_CHANNEL_NAME:
				stats.ChannelName = str
			case MQCA_CONNECTION_NAME:
				stats.ConnectionName = str
			}
		}
	}

	return stats
}

// parseMQIStats extracts MQI statistics from parameters
func (p *Parser) parseMQIStats(parameters []*PCFParameter) *MQIStatistics {
	stats := &MQIStatistics{}

	for _, param := range parameters {
		if val, ok := param.Value.(int32); ok {
			switch param.Parameter {
			case MQIAMO_OPENS:
				stats.Opens = val
			case MQIAMO_CLOSES:
				stats.Closes = val
			case MQIAMO_PUTS:
				stats.Puts = val
			case MQIAMO_GETS:
				stats.Gets = val
			case MQIAMO_COMMITS:
				stats.Commits = val
			case MQIAMO_BACKOUTS:
				stats.Backouts = val
			}
		} else if str, ok := param.Value.(string); ok {
			switch param.Parameter {
			case MQCA_APPL_NAME:
				stats.ApplicationName = str
			}
		}
	}

	return stats
}

// parseConnectionInfo extracts connection information from parameters
func (p *Parser) parseConnectionInfo(parameters []*PCFParameter) *ConnectionInfo {
	info := &ConnectionInfo{}

	for _, param := range parameters {
		if str, ok := param.Value.(string); ok {
			switch param.Parameter {
			case MQCA_CHANNEL_NAME:
				info.ChannelName = str
			case MQCA_CONNECTION_NAME:
				info.ConnectionName = str
			case MQCA_APPL_NAME:
				info.ApplicationName = str
			}
		}
	}

	return info
}

// parseOperationCounts extracts operation counts from parameters
func (p *Parser) parseOperationCounts(parameters []*PCFParameter) *OperationCounts {
	ops := &OperationCounts{}

	for _, param := range parameters {
		if val, ok := param.Value.(int32); ok {
			switch param.Parameter {
			case MQIAMO_GETS:
				ops.Gets = val
			case MQIAMO_PUTS:
				ops.Puts = val
			case MQIAMO_OPENS:
				ops.Opens = val
			case MQIAMO_CLOSES:
				ops.Closes = val
			case MQIAMO_COMMITS:
				ops.Commits = val
			case MQIAMO_BACKOUTS:
				ops.Backouts = val
			}
		}
	}

	return ops
}

// convertParameters converts PCF parameters to a map for JSON serialization
func (p *Parser) convertParameters(parameters []*PCFParameter) map[string]interface{} {
	result := make(map[string]interface{})

	for _, param := range parameters {
		key := fmt.Sprintf("param_%d", param.Parameter)
		result[key] = param.Value
	}

	return result
}

// cleanString removes null terminators and trims whitespace
func (p *Parser) cleanString(s string) string {
	// Remove null terminators
	for i, r := range s {
		if r == 0 {
			s = s[:i]
			break
		}
	}
	// Trim whitespace
	return s
}

// parseMQTimestamp parses IBM MQ timestamp format
func (p *Parser) parseMQTimestamp(timestamp string) (time.Time, error) {
	// MQ timestamp format: YYYY-MM-DD HH:MM:SS.mmm
	// Try multiple formats
	formats := []string{
		"2006-01-02 15:04:05.000",
		"2006-01-02 15:04:05",
		"20060102150405",
		"2006-01-02T15:04:05Z",
		"2006-01-02T15:04:05.000Z",
	}

	for _, format := range formats {
		if t, err := time.Parse(format, timestamp); err == nil {
			return t, nil
		}
	}

	return time.Time{}, fmt.Errorf("unable to parse timestamp: %s", timestamp)
}
