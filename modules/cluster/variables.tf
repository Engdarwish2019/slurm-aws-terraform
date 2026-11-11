variable "name" {
  description = "Cluster name, used as Slurm ClusterName and resource prefix."
  type        = string
}

variable "ami_id" {
  description = "AMI for all nodes (Rocky Linux 9 or another EL9 distribution)."
  type        = string
}

variable "subnet_id" {
  description = "Private subnet for all nodes."
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR of the private subnet. Static node IPs are derived from it."
  type        = string
}

variable "security_group_id" {
  description = "Security group shared by all nodes."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key for EBS volumes and the MUNGE key parameter."
  type        = string
}

variable "efs_dns_name" {
  description = "DNS name of the shared EFS file system."
  type        = string
}

variable "head_instance_type" {
  description = "Instance type for the head node."
  type        = string
}

variable "compute_instance_type" {
  description = "Instance type for CPU compute nodes."
  type        = string
}

variable "compute_node_count" {
  description = "Number of CPU compute nodes."
  type        = number
}

variable "gpu_instance_type" {
  description = "Instance type for GPU nodes."
  type        = string
}

variable "alarm_topic_arn" {
  description = "SNS topic for the EC2 status check alarms. Empty: recovery and reboot actions only."
  type        = string
  default     = ""
}

variable "gpu_cuda_toolkit" {
  description = "Install the CUDA toolkit and NCCL on GPU nodes."
  type        = bool
  default     = true
}

variable "gpu_node_count" {
  description = "Number of GPU nodes."
  type        = number
}

variable "root_volume_size" {
  description = "Root volume size in GiB."
  type        = number
}
