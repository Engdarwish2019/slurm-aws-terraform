data "aws_partition" "current" {}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Head node: Session Manager access plus permission to publish the MUNGE key.
resource "aws_iam_role" "head" {
  name               = "${var.name}-head"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "head_ssm" {
  role       = aws_iam_role.head.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "head" {
  statement {
    sid       = "PublishMungeKey"
    actions   = ["ssm:PutParameter", "ssm:GetParameter"]
    resources = [aws_ssm_parameter.munge_key.arn]
  }

  statement {
    sid       = "EncryptMungeKey"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "head" {
  name   = "munge-key-publisher"
  role   = aws_iam_role.head.id
  policy = data.aws_iam_policy_document.head.json
}

resource "aws_iam_instance_profile" "head" {
  name = "${var.name}-head"
  role = aws_iam_role.head.name
}

# Compute and GPU nodes: Session Manager access plus read-only access to the MUNGE key.
resource "aws_iam_role" "compute" {
  name               = "${var.name}-compute"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "compute_ssm" {
  role       = aws_iam_role.compute.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "compute" {
  statement {
    sid       = "ReadMungeKey"
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.munge_key.arn]
  }

  statement {
    sid       = "DecryptMungeKey"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "compute" {
  name   = "munge-key-reader"
  role   = aws_iam_role.compute.id
  policy = data.aws_iam_policy_document.compute.json
}

resource "aws_iam_instance_profile" "compute" {
  name = "${var.name}-compute"
  role = aws_iam_role.compute.name
}
