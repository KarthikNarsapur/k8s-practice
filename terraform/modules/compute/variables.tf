variable "project_name" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "control_plane_instance_type" {
  type = string
}

variable "worker_instance_type" {
  type = string
}

variable "worker_count" {
  type = number
}

variable "root_volume_size" {
  type = number
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "control_plane_sg_id" {
  type = string
}

variable "worker_sg_id" {
  type = string
}

variable "instance_profile_name" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "pod_cidr" {
  type = string
}

variable "service_cidr" {
  type = string
}

variable "auto_init_cluster" {
  type = bool
}

variable "ssm_param_prefix" {
  description = "Prefix for SSM parameters (join command)."
  type        = string
}

variable "region" {
  type = string
}
