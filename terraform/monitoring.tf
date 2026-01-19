# Konfiguracja monitoringu i alertów CloudWatch

# Temat SNS do wysyłania powiadomień o alarmach
# Wszystkie alarmy CloudWatch będą publikować wiadomości do tego tematu.
# Należy zasubskrybować ten temat (np. adresem e-mail), aby otrzymywać powiadomienia.
resource "aws_sns_topic" "alarms" {
  name = "${var.project_name}-alarms-topic"

  tags = {
    Name = "${var.project_name}-alarms-topic"
  }
}

# --- Alarmy dla instancji EC2 backendu ---

resource "aws_cloudwatch_metric_alarm" "backend_cpu_utilization" {
  alarm_name          = "${var.project_name}-backend-cpu-utilization-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alarm when backend EC2 CPU exceeds 80%"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    InstanceId = aws_instance.backend.id
  }
}

resource "aws_cloudwatch_metric_alarm" "backend_status_check_failed" {
  alarm_name          = "${var.project_name}-backend-status-check-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "Alarm when backend EC2 instance fails status checks"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    InstanceId = aws_instance.backend.id
  }
}

# --- Alarmy dla bazy danych RDS ---

resource "aws_cloudwatch_metric_alarm" "rds_cpu_utilization" {
  alarm_name          = "${var.project_name}-rds-cpu-utilization-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alarm when RDS CPU exceeds 80%"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage_space" {
  alarm_name          = "${var.project_name}-rds-free-storage-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "2000000000" # 2GB w bajtach
  alarm_description   = "Alarm when RDS free storage is less than 2GB"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_database_connections" {
  alarm_name          = "${var.project_name}-rds-connections-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "40"
  alarm_description   = "Alarm when RDS database connections exceed 40"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }
}

# --- Alarmy dla ALB ---

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${var.project_name}-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "1"
  alarm_description   = "Alarm when ALB has unhealthy hosts"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.backend.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  alarm_name          = "${var.project_name}-alb-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "120"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "Alarm when ALB target response time is over 1s"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.backend.arn_suffix
  }
}

