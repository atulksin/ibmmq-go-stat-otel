package config

import (
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestDefaultConfig(t *testing.T) {
	cfg := DefaultConfig()

	assert.NotNil(t, cfg)
	assert.Equal(t, "MQQM1", cfg.MQ.QueueManager)
	assert.Equal(t, "APP1.SVRCONN", cfg.MQ.Channel)
	assert.Equal(t, "localhost(1414)", cfg.MQ.ConnectionName)
	assert.Equal(t, "SYSTEM.ADMIN.STATISTICS.QUEUE", cfg.Collector.StatsQueue)
	assert.Equal(t, "SYSTEM.ADMIN.ACCOUNTING.QUEUE", cfg.Collector.AccountingQueue)
	assert.Equal(t, 60*time.Second, cfg.Collector.Interval)
	assert.Equal(t, 9090, cfg.Prometheus.Port)
	assert.Equal(t, "/metrics", cfg.Prometheus.Path)
	assert.Equal(t, "ibmmq", cfg.Prometheus.Namespace)
}

func TestConfigValidation(t *testing.T) {
	tests := []struct {
		name    string
		config  *Config
		wantErr bool
	}{
		{
			name:    "valid default config",
			config:  DefaultConfig(),
			wantErr: false,
		},
		{
			name: "missing queue manager",
			config: &Config{
				MQ: MQConfig{
					Channel:        "APP1.SVRCONN",
					ConnectionName: "localhost(1414)",
				},
				Collector:  DefaultConfig().Collector,
				Prometheus: DefaultConfig().Prometheus,
				Logging:    DefaultConfig().Logging,
			},
			wantErr: true,
		},
		{
			name: "missing channel",
			config: &Config{
				MQ: MQConfig{
					QueueManager:   "MQQM1",
					ConnectionName: "localhost(1414)",
				},
				Collector:  DefaultConfig().Collector,
				Prometheus: DefaultConfig().Prometheus,
				Logging:    DefaultConfig().Logging,
			},
			wantErr: true,
		},
		{
			name: "missing connection name",
			config: &Config{
				MQ: MQConfig{
					QueueManager: "MQQM1",
					Channel:      "APP1.SVRCONN",
				},
				Collector:  DefaultConfig().Collector,
				Prometheus: DefaultConfig().Prometheus,
				Logging:    DefaultConfig().Logging,
			},
			wantErr: true,
		},
		{
			name: "invalid interval",
			config: &Config{
				MQ: DefaultConfig().MQ,
				Collector: CollectorConfig{
					StatsQueue:      "SYSTEM.ADMIN.STATISTICS.QUEUE",
					AccountingQueue: "SYSTEM.ADMIN.ACCOUNTING.QUEUE",
					Interval:        500 * time.Millisecond, // Too short
				},
				Prometheus: DefaultConfig().Prometheus,
				Logging:    DefaultConfig().Logging,
			},
			wantErr: true,
		},
		{
			name: "invalid prometheus port",
			config: &Config{
				MQ:        DefaultConfig().MQ,
				Collector: DefaultConfig().Collector,
				Prometheus: PrometheusConfig{
					Port:      0, // Invalid port
					Path:      "/metrics",
					Namespace: "ibmmq",
				},
				Logging: DefaultConfig().Logging,
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if tt.wantErr {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

func TestLoadConfigFromEnvironment(t *testing.T) {
	// Set environment variables
	os.Setenv("IBMMQ_QUEUE_MANAGER", "TESTQM")
	os.Setenv("IBMMQ_CHANNEL", "TEST.SVRCONN")
	os.Setenv("IBMMQ_CONNECTION_NAME", "testhost(1414)")
	os.Setenv("IBMMQ_USER", "testuser")
	os.Setenv("IBMMQ_PASSWORD", "testpass")

	defer func() {
		os.Unsetenv("IBMMQ_QUEUE_MANAGER")
		os.Unsetenv("IBMMQ_CHANNEL")
		os.Unsetenv("IBMMQ_CONNECTION_NAME")
		os.Unsetenv("IBMMQ_USER")
		os.Unsetenv("IBMMQ_PASSWORD")
	}()

	cfg, err := LoadConfig("")
	require.NoError(t, err)
	require.NotNil(t, cfg)

	assert.Equal(t, "TESTQM", cfg.MQ.QueueManager)
	assert.Equal(t, "TEST.SVRCONN", cfg.MQ.Channel)
	assert.Equal(t, "testhost(1414)", cfg.MQ.ConnectionName)
	assert.Equal(t, "testuser", cfg.MQ.User)
	assert.Equal(t, "testpass", cfg.MQ.Password)
}

func TestConfigString(t *testing.T) {
	cfg := DefaultConfig()
	cfg.MQ.User = "testuser"

	str := cfg.String()
	assert.Contains(t, str, "MQQM1")
	assert.Contains(t, str, "APP1.SVRCONN")
	assert.Contains(t, str, "localhost(1414)")
	assert.Contains(t, str, "testuser")
	assert.Contains(t, str, "SYSTEM.ADMIN.STATISTICS.QUEUE")
	assert.Contains(t, str, "SYSTEM.ADMIN.ACCOUNTING.QUEUE")
}

func TestLoadConfigMissingFile(t *testing.T) {
	cfg, err := LoadConfig("/nonexistent/config.yaml")
	// Should handle missing file gracefully and return defaults
	if err != nil {
		// If there's an error, it should be about missing file
		assert.Contains(t, err.Error(), "config file")
	} else {
		// If no error, should have defaults
		assert.NotNil(t, cfg)
		assert.Equal(t, "MQQM1", cfg.MQ.QueueManager)
	}
}
