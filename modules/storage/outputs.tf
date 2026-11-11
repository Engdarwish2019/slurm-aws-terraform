output "file_system_id" {
  description = "EFS file system ID."
  value       = aws_efs_file_system.this.id
}

output "dns_name" {
  description = "DNS name used to mount the file system."
  value       = aws_efs_mount_target.this.file_system_dns_name
}
