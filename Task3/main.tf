# CPU Utilization Alarm

resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  for_each = toset(var.ec2_instance_ids)

  alarm_name          = "High-CPU-${each.value}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70

  dimensions = {
    InstanceId = each.value
  }

  alarm_description = "CPU usage above 70%"
}

# RAM Utilization Alarm

resource "aws_cloudwatch_metric_alarm" "memory_alarm" {
  for_each = toset(var.ec2_instance_ids)

  alarm_name          = "High-RAM-${each.value}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = 120
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    InstanceId = each.value
  }

  alarm_description = "RAM usage above 80%"
}

# Status Check Alarm

resource "aws_cloudwatch_metric_alarm" "status_alarm" {
  for_each = toset(var.ec2_instance_ids)

  alarm_name          = "StatusCheckFailed-${each.value}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0

  dimensions = {
    InstanceId = each.value
  }

  alarm_description = "Instance or system status check failed"
}

# CloudWatch Dashboard

resource "aws_cloudwatch_dashboard" "ec2_dashboard" {
  dashboard_name = "EC2-Monitoring-Dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        "type": "metric",
        "x": 0,
        "y": 0,
        "width": 12,
        "height": 6,
        "properties": {
          "metrics": [
            ["AWS/EC2", "CPUUtilization", "InstanceId", "i-023555bd5fbe5027c"],
            ["AWS/EC2", "CPUUtilization", "InstanceId", "i-03247ab1af88c7223"]
          ],
          "period": 300,
          "stat": "Average",
          "region": "ap-south-1",
          "title": "CPU Utilization - Selected Instances"
        }
      },
      {
        "type": "metric",
        "x": 0,
        "y": 6,
        "width": 12,
        "height": 6,
        "properties": {
          "metrics": [
            ["CWAgent", "mem_used_percent", "InstanceId", "i-023555bd5fbe5027c"],
            ["CWAgent", "mem_used_percent", "InstanceId", "i-03247ab1af88c7223"]
          ],
          "period": 300,
          "stat": "Average",
          "region": "ap-south-1",
          "title": "Memory Utilization - Selected Instances"
        }
      }
    ]
  })
}



