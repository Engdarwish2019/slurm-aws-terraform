# ---------------------------------------------------------------------------
# Operations: one KMS-encrypted SNS topic for everything that needs a human.
#  - EC2 status check alarms with automatic recovery (modules/cluster/alarms.tf)
#  - EFS getting close to its I/O limit
#  - AWS Health notices for EC2 in this account (scheduled maintenance, retirement)
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "alerts" {
  name              = "${var.cluster_name}-alerts"
  kms_master_key_id = aws_kms_key.cluster.arn
}

data "aws_iam_policy_document" "alerts_topic" {
  statement {
    sid       = "CloudWatchAlarmsAndEventBridge"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com", "events.amazonaws.com"]
    }

    # Only on behalf of this account (confused deputy protection).
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.alerts_topic.json
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alert_email == null ? 0 : 1

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# General Purpose EFS has an I/O operations ceiling. Many small-file jobs hitting it shows up
# as everything on /shared slowing down at once.
resource "aws_cloudwatch_metric_alarm" "efs_io_limit" {
  alarm_name          = "${var.cluster_name}-efs-io-limit"
  alarm_description   = "/shared is above 90% of the EFS I/O limit: small-file-heavy jobs slow everyone down. Move scratch to local disk or FSx for Lustre."
  namespace           = "AWS/EFS"
  metric_name         = "PercentIOLimit"
  dimensions          = { FileSystemId = module.storage.file_system_id }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 3
  threshold           = 90
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_event_rule" "ec2_health" {
  name        = "${var.cluster_name}-ec2-health"
  description = "AWS Health notices for EC2 in this account: scheduled maintenance, instance retirement, hardware issues."

  event_pattern = jsonencode({
    source        = ["aws.health"]
    "detail-type" = ["AWS Health Event"]
    detail = {
      service = ["EC2"]
    }
  })
}

resource "aws_cloudwatch_event_target" "ec2_health" {
  rule = aws_cloudwatch_event_rule.ec2_health.name
  arn  = aws_sns_topic.alerts.arn
}
