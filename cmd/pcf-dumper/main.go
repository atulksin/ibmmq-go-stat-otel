package main

import (
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"log"

	"github.com/atulksin/ibmmq-go-stat-otel/pkg/config"
	"github.com/atulksin/ibmmq-go-stat-otel/pkg/mqclient"
	"github.com/sirupsen/logrus"
)

func main() {
	// Load configuration
	cfg := &config.MQConfig{
		QueueManager:   "MQQM1",
		Channel:        "APP1.SVRCONN",
		ConnectionName: "127.0.0.1(5200)",
	}

	// Create logger
	logger := logrus.New()
	logger.SetLevel(logrus.InfoLevel)

	// Create MQ client
	client := mqclient.NewMQClient(cfg, logger)

	// Connect
	if err := client.Connect(); err != nil {
		log.Fatalf("Failed to connect: %v", err)
	}
	defer client.Disconnect()

	// Open queues
	if err := client.OpenStatsQueue("SYSTEM.ADMIN.STATISTICS.QUEUE"); err != nil {
		log.Printf("Failed to open statistics queue: %v", err)
	}
	if err := client.OpenAccountingQueue("SYSTEM.ADMIN.ACCOUNTING.QUEUE"); err != nil {
		log.Printf("Failed to open accounting queue: %v", err)
	}

	fmt.Println("=== IBM MQ PCF Data Dumper ===")

	// Get accounting messages
	fmt.Println("\n--- ACCOUNTING MESSAGES ---")
	acctMessages, err := client.GetAllMessages("accounting")
	if err != nil {
		log.Printf("Error getting accounting messages: %v", err)
	} else {
		fmt.Printf("Retrieved %d accounting messages\n", len(acctMessages))

		for i, msg := range acctMessages {
			msgData := msg.Data
			fmt.Printf("\n=== Accounting Message %d ===\n", i+1)
			fmt.Printf("Length: %d bytes\n", len(msgData))

			// Show hex dump of first 64 bytes
			fmt.Printf("Hex dump (first 64 bytes):\n")
			if len(msgData) > 64 {
				fmt.Printf("%s\n", hex.Dump(msgData[:64]))
			} else {
				fmt.Printf("%s\n", hex.Dump(msgData))
			}

			// Try to parse PCF header
			if len(msgData) >= 36 {
				fmt.Printf("PCF Header Analysis:\n")
				fmt.Printf("  Type (BE):           %d\n", binary.BigEndian.Uint32(msgData[0:4]))
				fmt.Printf("  Type (LE):           %d\n", binary.LittleEndian.Uint32(msgData[0:4]))
				fmt.Printf("  StrucLength (BE):    %d\n", binary.BigEndian.Uint32(msgData[4:8]))
				fmt.Printf("  StrucLength (LE):    %d\n", binary.LittleEndian.Uint32(msgData[4:8]))
				fmt.Printf("  Command (BE):        %d\n", binary.BigEndian.Uint32(msgData[12:16]))
				fmt.Printf("  Command (LE):        %d\n", binary.LittleEndian.Uint32(msgData[12:16]))
				fmt.Printf("  ParamCount (BE):     %d\n", binary.BigEndian.Uint32(msgData[32:36]))
				fmt.Printf("  ParamCount (LE):     %d\n", binary.LittleEndian.Uint32(msgData[32:36]))
			}

			if i >= 2 { // Limit to first 3 messages
				fmt.Printf("... (showing first 3 messages only)\n")
				break
			}
		}
	}

	// Get statistics messages
	fmt.Println("\n--- STATISTICS MESSAGES ---")
	statsMessages, err := client.GetAllMessages("stats")
	if err != nil {
		log.Printf("Error getting statistics messages: %v", err)
	} else {
		fmt.Printf("Retrieved %d statistics messages\n", len(statsMessages))

		for i, msg := range statsMessages {
			msgData := msg.Data
			fmt.Printf("\n=== Statistics Message %d ===\n", i+1)
			fmt.Printf("Length: %d bytes\n", len(msgData))

			// Show hex dump of first 64 bytes
			fmt.Printf("Hex dump (first 64 bytes):\n")
			if len(msgData) > 64 {
				fmt.Printf("%s\n", hex.Dump(msgData[:64]))
			} else {
				fmt.Printf("%s\n", hex.Dump(msgData))
			}

			// Try to parse PCF header
			if len(msgData) >= 36 {
				fmt.Printf("PCF Header Analysis:\n")
				fmt.Printf("  Type (BE):           %d\n", binary.BigEndian.Uint32(msgData[0:4]))
				fmt.Printf("  Type (LE):           %d\n", binary.LittleEndian.Uint32(msgData[0:4]))
				fmt.Printf("  StrucLength (BE):    %d\n", binary.BigEndian.Uint32(msgData[4:8]))
				fmt.Printf("  StrucLength (LE):    %d\n", binary.LittleEndian.Uint32(msgData[4:8]))
				fmt.Printf("  Command (BE):        %d\n", binary.BigEndian.Uint32(msgData[12:16]))
				fmt.Printf("  Command (LE):        %d\n", binary.LittleEndian.Uint32(msgData[12:16]))
				fmt.Printf("  ParamCount (BE):     %d\n", binary.BigEndian.Uint32(msgData[32:36]))
				fmt.Printf("  ParamCount (LE):     %d\n", binary.LittleEndian.Uint32(msgData[32:36]))
			}
		}
	}

	fmt.Println("\n=== Analysis Complete ===")
	fmt.Println("This raw data shows the actual PCF format used by IBM MQ.")
	fmt.Println("Look for ipprocs (input processes/readers) and opprocs (output processes/writers) in the data.")
}
