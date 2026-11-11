variable "name" {
  description = "Name prefix for storage resources."
  type        = string
}

variable "subnet_id" {
  description = "Subnet for the EFS mount target."
  type        = string
}

variable "security_group_id" {
  description = "Security group attached to the EFS mount target."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key for encryption at rest."
  type        = string
}
