variable "name" {
  description = "Name prefix for network resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "availability_zone" {
  description = "Availability zone for the subnets."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key used to encrypt the flow log group."
  type        = string
}

variable "enable_flow_logs" {
  description = "Send VPC flow logs to CloudWatch Logs."
  type        = bool
}

variable "log_retention_days" {
  description = "Retention for the flow log group."
  type        = number
}
