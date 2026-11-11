resource "aws_security_group" "nodes" {
  name        = "${var.cluster_name}-nodes"
  description = "Slurm head and compute nodes"
  vpc_id      = module.network.vpc_id

  tags = {
    Name = "${var.cluster_name}-nodes"
  }
}

resource "aws_vpc_security_group_ingress_rule" "nodes_intra_cluster" {
  security_group_id            = aws_security_group.nodes.id
  description                  = "Slurm, MUNGE and MPI traffic between cluster nodes"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.nodes.id
}

resource "aws_vpc_security_group_egress_rule" "nodes_intra_cluster" {
  security_group_id            = aws_security_group.nodes.id
  description                  = "Slurm, MUNGE and MPI traffic between cluster nodes"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.nodes.id
}

resource "aws_vpc_security_group_egress_rule" "nodes_https" {
  security_group_id = aws_security_group.nodes.id
  description       = "HTTPS to package repositories, SSM and AWS APIs"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "nodes_http" {
  security_group_id = aws_security_group.nodes.id
  description       = "HTTP to distribution mirrors (packages are GPG-verified by dnf)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "nodes_nfs" {
  security_group_id            = aws_security_group.nodes.id
  description                  = "NFS to the shared EFS file system"
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  referenced_security_group_id = aws_security_group.efs.id
}

resource "aws_security_group" "efs" {
  name        = "${var.cluster_name}-efs"
  description = "EFS mount target, reachable from cluster nodes only"
  vpc_id      = module.network.vpc_id

  tags = {
    Name = "${var.cluster_name}-efs"
  }
}

resource "aws_vpc_security_group_ingress_rule" "efs_nfs" {
  security_group_id            = aws_security_group.efs.id
  description                  = "NFS from cluster nodes"
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  referenced_security_group_id = aws_security_group.nodes.id
}
