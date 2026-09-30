###############################################################################
# Root module — wires network, iam and compute together.
###############################################################################

data "aws_availability_zones" "available" {
  state = "available"
}

# Resolve the latest Ubuntu 24.04 LTS AMI from the public SSM parameter,
# so we never hardcode an AMI id (and it stays current per region).
data "aws_ssm_parameter" "ubuntu_ami" {
  name = var.ubuntu_ami_ssm_parameter
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

module "network" {
  source = "./modules/network"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  azs                  = local.azs
  public_subnet_cidrs  = slice(var.public_subnet_cidrs, 0, var.az_count)
  private_subnet_cidrs = slice(var.private_subnet_cidrs, 0, var.az_count)
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  nodeport_range       = "30000-32767"
}

module "iam" {
  source = "./modules/iam"

  project_name      = var.project_name
  ssm_parameter_arn = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/*"
}

data "aws_caller_identity" "current" {}

module "compute" {
  source = "./modules/compute"

  project_name                = var.project_name
  ami_id                      = data.aws_ssm_parameter.ubuntu_ami.value
  control_plane_instance_type = var.control_plane_instance_type
  worker_instance_type        = var.worker_instance_type
  worker_count                = var.worker_count
  root_volume_size            = var.root_volume_size

  private_subnet_ids    = module.network.private_subnet_ids
  control_plane_sg_id   = module.network.control_plane_sg_id
  worker_sg_id          = module.network.worker_sg_id
  instance_profile_name = module.iam.instance_profile_name

  kubernetes_version = var.kubernetes_version
  pod_cidr           = var.pod_cidr
  service_cidr       = var.service_cidr
  auto_init_cluster  = var.auto_init_cluster
  ssm_param_prefix   = var.project_name
  region             = var.region

  nat_dependency = module.network.nat_route_ids
}
