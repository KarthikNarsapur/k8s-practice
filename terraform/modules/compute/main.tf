###############################################################################
# Compute: 1 control-plane + N workers in private subnets.
# Access is via SSM Session Manager only (no key pair, no public IP).
###############################################################################

locals {
  # Render the common bootstrap once; inject into control-plane & worker.
  common_bootstrap = templatefile("${path.module}/templates/common-bootstrap.sh.tftpl", {
    kubernetes_version = var.kubernetes_version
  })

  control_plane_user_data = templatefile("${path.module}/templates/control-plane.sh.tftpl", {
    common_bootstrap   = local.common_bootstrap
    kubernetes_version = var.kubernetes_version
    pod_cidr           = var.pod_cidr
    service_cidr       = var.service_cidr
    auto_init_cluster  = tostring(var.auto_init_cluster)
    ssm_param_prefix   = var.ssm_param_prefix
    region             = var.region
  })

  worker_user_data = templatefile("${path.module}/templates/worker.sh.tftpl", {
    common_bootstrap  = local.common_bootstrap
    auto_init_cluster = tostring(var.auto_init_cluster)
    ssm_param_prefix  = var.ssm_param_prefix
    region            = var.region
  })
}

###############################################################################
# Control-plane node
###############################################################################
resource "aws_instance" "control_plane" {
  ami                    = var.ami_id
  instance_type          = var.control_plane_instance_type
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.control_plane_sg_id]
  iam_instance_profile   = var.instance_profile_name
  user_data              = local.control_plane_user_data
  # Re-create the node if its bootstrap (user_data) changes.
  user_data_replace_on_change = true

  # No public IP: reached via SSM only.
  associate_public_ip_address = false

  metadata_options {
    http_tokens   = "required" # IMDSv2
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-control-plane"
    Role = "control-plane"
  }

  # Do not boot (and run apt-get) until the NAT egress route exists.
  depends_on = [var.nat_dependency]
}

###############################################################################
# Worker nodes (spread across private subnets, round-robin)
###############################################################################
resource "aws_instance" "worker" {
  count                  = var.worker_count
  ami                    = var.ami_id
  instance_type          = var.worker_instance_type
  subnet_id              = var.private_subnet_ids[count.index % length(var.private_subnet_ids)]
  vpc_security_group_ids = [var.worker_sg_id]
  iam_instance_profile   = var.instance_profile_name
  user_data              = local.worker_user_data
  # Re-create the node if its bootstrap (user_data) changes.
  user_data_replace_on_change = true

  associate_public_ip_address = false

  metadata_options {
    http_tokens   = "required" # IMDSv2
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-worker-${count.index + 1}"
    Role = "worker"
  }

  # Workers depend on the control-plane publishing its join command to SSM,
  # but they poll for it, so we only need the CP resource to exist first.
  # Also wait for NAT egress so early apt-get calls succeed.
  depends_on = [aws_instance.control_plane, var.nat_dependency]
}
