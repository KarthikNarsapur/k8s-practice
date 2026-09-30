###############################################################################
# IAM role + instance profile for cluster nodes.
# Grants ONLY:
#   - AmazonSSMManagedInstanceCore  (Session Manager, no SSH keys needed)
#   - scoped read/write to the join-token SSM parameter under /<project>/*
#   - KMS decrypt for SecureString parameters (aws/ssm managed key)
###############################################################################

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.project_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = {
    Name = "${var.project_name}-node-role"
  }
}

# Managed policy that enables SSM Session Manager + agent functionality.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Scoped inline policy for the kubeadm join token in Parameter Store.
data "aws_iam_policy_document" "ssm_params" {
  statement {
    sid = "JoinTokenParams"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:PutParameter",
      "ssm:DeleteParameter"
    ]
    resources = [var.ssm_parameter_arn]
  }

  # SecureString parameters are encrypted with the aws/ssm managed KMS key.
  statement {
    sid = "KmsForSecureString"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${data.aws_region.current.name}.amazonaws.com"]
    }
  }
}

data "aws_region" "current" {}

resource "aws_iam_role_policy" "ssm_params" {
  name   = "${var.project_name}-ssm-params"
  role   = aws_iam_role.node.id
  policy = data.aws_iam_policy_document.ssm_params.json
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.project_name}-node-profile"
  role = aws_iam_role.node.name
}
