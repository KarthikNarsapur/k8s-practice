# Credentials are NEVER hardcoded here.
# The provider resolves credentials from the standard AWS chain:
#   environment vars, shared config/credentials file, SSO, or an
#   instance/role profile. Set your region via the `region` variable.

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "lab"
      ManagedBy   = "terraform"
    }
  }
}
