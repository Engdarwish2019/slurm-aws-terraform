output "file_system_id" {
  description = "EFS file system ID."
  value       = aws_efs_file_system.this.id
}

output "dns_name" {
  description = "DNS name used to mount the file system. Read from the mount target so nodes wait for it before booting."
  value       = aws_efs_mount_target.this.dns_name
}
