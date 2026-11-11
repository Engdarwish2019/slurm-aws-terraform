data "aws_ami" "rocky9" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["792107900819"]

  filter {
    name   = "name"
    values = ["Rocky-9-EC2-Base-9.*x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  availability_zone = coalesce(var.availability_zone, "${var.region}a")
  ami_id            = coalesce(var.ami_id, one(data.aws_ami.rocky9[*].id))
}

module "network" {
  source = "./modules/network"

  name               = var.cluster_name
  vpc_cidr           = var.vpc_cidr
  availability_zone  = local.availability_zone
  kms_key_arn        = aws_kms_key.cluster.arn
  enable_flow_logs   = var.enable_flow_logs
  log_retention_days = var.log_retention_days
}

module "storage" {
  source = "./modules/storage"

  name              = var.cluster_name
  subnet_id         = module.network.private_subnet_id
  security_group_id = aws_security_group.efs.id
  kms_key_arn       = aws_kms_key.cluster.arn
}

module "cluster" {
  source = "./modules/cluster"

  name                  = var.cluster_name
  ami_id                = local.ami_id
  subnet_id             = module.network.private_subnet_id
  subnet_cidr           = module.network.private_subnet_cidr
  security_group_id     = aws_security_group.nodes.id
  kms_key_arn           = aws_kms_key.cluster.arn
  efs_dns_name          = module.storage.dns_name
  head_instance_type    = var.head_instance_type
  compute_instance_type = var.compute_instance_type
  compute_node_count    = var.compute_node_count
  gpu_instance_type     = var.gpu_instance_type
  gpu_node_count        = var.gpu_node_count
  gpu_cuda_toolkit      = var.gpu_cuda_toolkit
  alarm_topic_arn       = aws_sns_topic.alerts.arn
  root_volume_size      = var.root_volume_size

  depends_on = [module.storage]
}
