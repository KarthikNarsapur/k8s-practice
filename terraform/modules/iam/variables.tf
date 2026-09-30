variable "project_name" {
  type = string
}

variable "ssm_parameter_arn" {
  description = "ARN pattern for SSM parameters this node may read/write (join token). Scoped to /<project>/*"
  type        = string
}
