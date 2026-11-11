variable "region" {
  description = "AWS region to deploy the cluster in."
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment name, used for tagging."
  type        = string
  default     = "lab"
}

variable "cluster_name" {
  description = "Slurm cluster name. Also used as a prefix for AWS resource names."
  type        = string
  default     = "hpc-lab"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.cluster_name))
    error_message = "Use 3-21 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the cluster VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zone" {
  description = "Availability zone for the cluster. Defaults to the a zone of the region (for example eu-central-1a). Pick a zone that offers your instance types."
  type        = string
  default     = null
}

variable "ami_id" {
  description = "AMI for all nodes. Defaults to the latest official Rocky Linux 9 AMI."
  type        = string
  default     = null
}

variable "head_instance_type" {
  description = "Instance type for the head node (slurmctld, slurmdbd, MariaDB)."
  type        = string
  default     = "c6i.large"
}

variable "compute_instance_type" {
  description = "Instance type for CPU compute nodes."
  type        = string
  default     = "c6i.xlarge"
}

variable "compute_node_count" {
  description = "Number of CPU compute nodes."
  type        = number
  default     = 2

  validation {
    condition     = var.compute_node_count >= 1 && var.compute_node_count <= 40
    error_message = "compute_node_count must be between 1 and 40."
  }
}

variable "gpu_instance_type" {
  description = "Instance type for GPU nodes (NVIDIA)."
  type        = string
  default     = "g5.xlarge"
}

variable "alert_email" {
  description = "Email address subscribed to the alerts topic (AWS sends a confirmation mail). Null: no subscription."
  type        = string
  default     = null
}

variable "gpu_cuda_toolkit" {
  description = "Install the CUDA toolkit and NCCL on GPU nodes (needed to build nccl-tests; adds a few minutes to the first boot)."
  type        = bool
  default     = true
}

variable "gpu_node_count" {
  description = "Number of GPU nodes. Keep 0 unless you need the gpu partition, GPU instances are expensive."
  type        = number
  default     = 0

  validation {
    condition     = var.gpu_node_count >= 0 && var.gpu_node_count <= 20
    error_message = "gpu_node_count must be between 0 and 20."
  }
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB for every node."
  type        = number
  default     = 50
}

variable "enable_flow_logs" {
  description = "Send VPC flow logs to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Retention for CloudWatch log groups."
  type        = number
  default     = 365
}
