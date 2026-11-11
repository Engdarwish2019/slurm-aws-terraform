output "head_instance_id" {
  description = "Instance ID of the head node."
  value       = aws_instance.head.id
}

output "nodes" {
  description = "Map of Slurm node name to private IP."
  value = merge(
    { (local.head.name) = local.head.ip },
    { for n in local.compute_nodes : n.name => n.ip },
    { for n in local.gpu_nodes : n.name => n.ip },
  )
}

output "slurm_conf_b64" {
  description = "Rendered slurm.conf, base64 encoded."
  value       = base64encode(local.slurm_conf)
}

output "munge_key_parameter" {
  description = "SSM parameter that holds the MUNGE key."
  value       = aws_ssm_parameter.munge_key.name
}
