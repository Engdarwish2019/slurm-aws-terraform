output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "private_subnet_id" {
  description = "Private subnet that hosts all cluster nodes."
  value       = aws_subnet.private.id
}

output "private_subnet_cidr" {
  description = "CIDR of the private subnet. Node IPs are derived from it."
  value       = aws_subnet.private.cidr_block
}
