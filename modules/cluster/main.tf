data "aws_region" "current" {}

data "aws_ec2_instance_type" "compute" {
  instance_type = var.compute_instance_type
}

data "aws_ec2_instance_type" "gpu" {
  instance_type = var.gpu_instance_type
}

locals {
  head = {
    name = "head"
    ip   = cidrhost(var.subnet_cidr, 10)
  }

  compute_nodes = [
    for i in range(var.compute_node_count) : {
      name = format("compute-%02d", i + 1)
      ip   = cidrhost(var.subnet_cidr, 20 + i)
    }
  ]

  gpu_nodes = [
    for i in range(var.gpu_node_count) : {
      name = format("gpu-%02d", i + 1)
      ip   = cidrhost(var.subnet_cidr, 70 + i)
    }
  ]

  compute_shape = {
    cpus    = data.aws_ec2_instance_type.compute.default_vcpus
    cores   = data.aws_ec2_instance_type.compute.default_cores
    threads = data.aws_ec2_instance_type.compute.default_threads_per_core
    memory  = floor(data.aws_ec2_instance_type.compute.memory_size * 0.85)
  }

  gpu_shape = {
    cpus    = data.aws_ec2_instance_type.gpu.default_vcpus
    cores   = data.aws_ec2_instance_type.gpu.default_cores
    threads = data.aws_ec2_instance_type.gpu.default_threads_per_core
    memory  = floor(data.aws_ec2_instance_type.gpu.memory_size * 0.85)
    gpus    = sum(concat([0], [for g in data.aws_ec2_instance_type.gpu.gpus : g.count]))
  }

  gpu_device_files = local.gpu_shape.gpus <= 1 ? "/dev/nvidia0" : "/dev/nvidia[0-${local.gpu_shape.gpus - 1}]"

  slurm_conf = templatefile("${path.module}/templates/slurm.conf.tftpl", {
    cluster_name  = var.name
    head          = local.head
    compute_nodes = local.compute_nodes
    gpu_nodes     = local.gpu_nodes
    compute       = local.compute_shape
    gpu           = local.gpu_shape
    compute_list  = join(",", [for n in local.compute_nodes : n.name])
    gpu_list      = join(",", [for n in local.gpu_nodes : n.name])
  })

  gres_conf = templatefile("${path.module}/templates/gres.conf.tftpl", {
    gpu_list     = join(",", [for n in local.gpu_nodes : n.name])
    device_files = local.gpu_device_files
  })

  base_vars = {
    region       = data.aws_region.current.name
    cluster_name = var.name
    efs_dns_name = var.efs_dns_name
    munge_param  = aws_ssm_parameter.munge_key.name
    kms_key_arn  = var.kms_key_arn
  }

  head_user_data = join("\n", [
    templatefile("${path.module}/templates/common.sh.tftpl", merge(local.base_vars, {
      node_name = local.head.name
      hosts     = concat([local.head], local.compute_nodes, local.gpu_nodes)
    })),
    templatefile("${path.module}/templates/head.sh.tftpl", {
      slurm_conf  = base64encode(local.slurm_conf)
      cgroup_conf = base64encode(file("${path.module}/templates/cgroup.conf"))
      gres_conf   = base64encode(local.gres_conf)
    }),
  ])
}

# Placeholder only. The head node generates the real MUNGE key at first boot and
# overwrites this value, so the secret never appears in code or Terraform state.
resource "aws_ssm_parameter" "munge_key" {
  name        = "/${var.name}/slurm/munge-key"
  description = "MUNGE key for ${var.name}, written by the head node at first boot"
  type        = "SecureString"
  key_id      = var.kms_key_arn
  value       = "pending"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_placement_group" "compute" {
  name     = "${var.name}-compute"
  strategy = "cluster"
}

resource "aws_instance" "head" {
  ami                    = var.ami_id
  instance_type          = var.head_instance_type
  subnet_id              = var.subnet_id
  private_ip             = local.head.ip
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.head.name
  monitoring             = true
  ebs_optimized          = true
  user_data              = local.head_user_data

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
    kms_key_id  = var.kms_key_arn
  }

  # slurm.conf changes after resizing are pushed with scripts/push-slurm-conf.sh,
  # so the head node (and its accounting database) is never rebuilt for them.
  lifecycle {
    ignore_changes = [user_data, ami]
  }

  tags = {
    Name = "${var.name}-head"
    Role = "slurm-controller"
  }
}

resource "aws_instance" "compute" {
  count = length(local.compute_nodes)

  ami                    = var.ami_id
  instance_type          = var.compute_instance_type
  subnet_id              = var.subnet_id
  private_ip             = local.compute_nodes[count.index].ip
  placement_group        = aws_placement_group.compute.id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.compute.name
  monitoring             = true
  ebs_optimized          = true

  user_data = join("\n", [
    templatefile("${path.module}/templates/common.sh.tftpl", merge(local.base_vars, {
      node_name = local.compute_nodes[count.index].name
      hosts     = [local.head, local.compute_nodes[count.index]]
    })),
    templatefile("${path.module}/templates/compute.sh.tftpl", {
      head_name = local.head.name
      is_gpu    = false
    }),
  ])

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
    kms_key_id  = var.kms_key_arn
  }

  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "${var.name}-${local.compute_nodes[count.index].name}"
    Role = "slurm-compute"
  }

  depends_on = [aws_instance.head]
}

resource "aws_instance" "gpu" {
  count = length(local.gpu_nodes)

  ami                    = var.ami_id
  instance_type          = var.gpu_instance_type
  subnet_id              = var.subnet_id
  private_ip             = local.gpu_nodes[count.index].ip
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.compute.name
  monitoring             = true
  ebs_optimized          = true

  user_data = join("\n", [
    templatefile("${path.module}/templates/common.sh.tftpl", merge(local.base_vars, {
      node_name = local.gpu_nodes[count.index].name
      hosts     = [local.head, local.gpu_nodes[count.index]]
    })),
    templatefile("${path.module}/templates/compute.sh.tftpl", {
      head_name = local.head.name
      is_gpu    = true
    }),
  ])

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = max(var.root_volume_size, 100)
    encrypted   = true
    kms_key_id  = var.kms_key_arn
  }

  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "${var.name}-${local.gpu_nodes[count.index].name}"
    Role = "slurm-gpu"
  }

  depends_on = [aws_instance.head]
}
