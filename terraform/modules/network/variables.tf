variable "project_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  description = "List of availability zone names to use."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "enable_nat_gateway" {
  type = bool
}

variable "single_nat_gateway" {
  type = bool
}

variable "nodeport_range" {
  description = "NodePort port range to allow within the VPC."
  type        = string
  default     = "30000-32767"
}
