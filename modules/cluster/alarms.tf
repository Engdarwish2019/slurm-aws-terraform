# EC2 status check alarms for every node.
#
# A failed *system* check means the host under the instance lost power, network or hardware.
# EC2 recovery fixes that by itself: same instance ID, private IP and EBS volumes, on healthy
# hardware. Recovery is not available for instance types with instance store disks (g5, for
# example), so those nodes only notify; the Slurm health check already drains them.
# A failed *instance* check on the head node (kernel or OS hang) triggers a reboot:
# slurmctld, slurmdbd and MariaDB start again on boot.

data "aws_ec2_instance_type" "head" {
  instance_type = var.head_instance_type
}

locals {
  recover_action = "arn:${data.aws_partition.current.partition}:automate:${data.aws_region.current.name}:ec2:recover"
  reboot_action  = "arn:${data.aws_partition.current.partition}:automate:${data.aws_region.current.name}:ec2:reboot"

  monitored_nodes = merge(
    {
      (local.head.name) = {
        id          = aws_instance.head.id
        recoverable = !data.aws_ec2_instance_type.head.instance_storage_supported
      }
    },
    {
      for i, n in local.compute_nodes : n.name => {
        id          = aws_instance.compute[i].id
        recoverable = !data.aws_ec2_instance_type.compute.instance_storage_supported
      }
    },
    {
      for i, n in local.gpu_nodes : n.name => {
        id          = aws_instance.gpu[i].id
        recoverable = !data.aws_ec2_instance_type.gpu.instance_storage_supported
      }
    },
  )
}

resource "aws_cloudwatch_metric_alarm" "system_check" {
  for_each = local.monitored_nodes

  alarm_name = "${var.name}-${each.key}-system-check"
  alarm_description = (each.value.recoverable
    ? "Host failure under ${each.key}: EC2 recovers the instance onto healthy hardware."
    : "Host failure under ${each.key}. Its instance store disks rule out EC2 recovery: stop and start it."
  )
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_System"
  dimensions          = { InstanceId = each.value.id }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = compact([each.value.recoverable ? local.recover_action : "", var.alarm_topic_arn])
  ok_actions          = compact([var.alarm_topic_arn])
}

resource "aws_cloudwatch_metric_alarm" "head_instance_check" {
  alarm_name          = "${var.name}-head-instance-check"
  alarm_description   = "The head node's OS stopped responding: reboot it. Slurm and its database start again on boot."
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_Instance"
  dimensions          = { InstanceId = aws_instance.head.id }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = compact([local.reboot_action, var.alarm_topic_arn])
  ok_actions          = compact([var.alarm_topic_arn])
}
