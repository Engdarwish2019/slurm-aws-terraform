output "region" {
  description = "Region the cluster runs in."
  value       = var.region
}

output "head_instance_id" {
  description = "Instance ID of the head node."
  value       = module.cluster.head_instance_id
}

output "connect" {
  description = "Open a shell on the head node through SSM Session Manager."
  value       = "aws ssm start-session --region ${var.region} --target ${module.cluster.head_instance_id}"
}

output "nodes" {
  description = "Slurm node names and private IPs."
  value       = module.cluster.nodes
}

output "shared_filesystem" {
  description = "EFS file system mounted at /shared on every node."
  value       = module.storage.dns_name
}

output "slurm_conf_b64" {
  description = "Rendered slurm.conf (base64). Used by scripts/push-slurm-conf.sh after resizing."
  value       = module.cluster.slurm_conf_b64
}

output "alerts_topic_arn" {
  description = "SNS topic for EC2 recovery, EFS and AWS Health alerts. Subscribe more endpoints here."
  value       = aws_sns_topic.alerts.arn
}
