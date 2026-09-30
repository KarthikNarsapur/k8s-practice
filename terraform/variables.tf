###############################################################################
# General
###############################################################################

variable "project_name" {
  description = "Name prefix applied to all resources and tags."
  type        = string
  default     = "k8s-lab"
}

variable "region" {
  description = "AWS region to deploy into. Configurable; not hardcoded."
  type        = string
  default     = "us-east-1"
}

###############################################################################
# Networking
###############################################################################

variable "vpc_cidr" {
  description = "CIDR block for the lab VPC."
  type        = string
  default     = "10.50.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to spread subnets across."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 3
    error_message = "az_count must be between 1 and 3."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)."
  type        = list(string)
  default     = ["10.50.0.0/20", "10.50.32.0/20"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)."
  type        = list(string)
  default     = ["10.50.16.0/20", "10.50.48.0/20"]
}

variable "enable_nat_gateway" {
  description = "Create a NAT Gateway so private nodes reach the internet (image/package pulls). Disable to save cost if using VPC endpoints instead."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway (cheaper) instead of one per AZ."
  type        = bool
  default     = true
}

###############################################################################
# Compute / cluster
###############################################################################

variable "control_plane_instance_type" {
  description = "EC2 instance type for the control-plane node."
  type        = string
  default     = "t3.medium"
}

variable "worker_instance_type" {
  description = "EC2 instance type for worker nodes."
  type        = string
  default     = "t3.medium"
}

variable "worker_count" {
  description = "Number of worker nodes. Configurable for cost control."
  type        = number
  default     = 3

  validation {
    condition     = var.worker_count >= 1 && var.worker_count <= 6
    error_message = "worker_count must be between 1 and 6."
  }
}

variable "root_volume_size" {
  description = "Root EBS volume size (GiB) per node."
  type        = number
  default     = 30
}

variable "kubernetes_version" {
  description = "Kubernetes minor version (used to select the pkgs.k8s.io repo, e.g. 1.33)."
  type        = string
  default     = "1.33"
}

variable "pod_cidr" {
  description = "Pod network CIDR passed to kubeadm and Calico."
  type        = string
  default     = "192.168.0.0/16"
}

variable "service_cidr" {
  description = "Service network CIDR passed to kubeadm."
  type        = string
  default     = "10.96.0.0/12"
}

variable "auto_init_cluster" {
  description = "If true, user_data automatically runs kubeadm init/join to form the cluster on first boot. If false, you bootstrap manually (more instructive)."
  type        = bool
  default     = true
}

variable "ubuntu_ami_ssm_parameter" {
  description = "SSM public parameter that resolves the latest Ubuntu 24.04 LTS AMI for the region."
  type        = string
  default     = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}
