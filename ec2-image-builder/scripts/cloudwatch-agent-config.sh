#!/bin/bash
# CloudWatch Agent Configuration Script for ISMS Monitoring
set -e

echo "Starting CloudWatch Agent configuration..."

# Create CloudWatch Agent configuration directory
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc/

# Create CloudWatch Agent configuration file
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "metrics": {
    "namespace": "ISMS/GoldenAMI",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60,
        "totalcpu": false
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "diskio": {
        "measurement": [
          "io_time"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      },
      "netstat": {
        "measurement": [
          "tcp_established",
          "tcp_time_wait"
        ],
        "metrics_collection_interval": 60
      },
      "swap": {
        "measurement": [
          "swap_used_percent"
        ],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "ISMS-GoldenAMI-SystemLogs",
            "log_stream_name": "{instance_id}-messages"
          },
          {
            "file_path": "/var/log/secure",
            "log_group_name": "ISMS-GoldenAMI-SecurityLogs",
            "log_stream_name": "{instance_id}-secure"
          },
          {
            "file_path": "/var/log/auth.log",
            "log_group_name": "ISMS-GoldenAMI-AuthLogs",
            "log_stream_name": "{instance_id}-auth"
          }
        ]
      }
    }
  }
}
EOF

# Enable CloudWatch Agent service
systemctl enable amazon-cloudwatch-agent

echo "CloudWatch Agent configuration completed successfully!"