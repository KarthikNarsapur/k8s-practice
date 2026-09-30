# Remote state in S3.
# The bucket was created out-of-band (Terraform cannot manage the bucket that
# stores its own state). It has versioning + encryption + public-access-block.
# State locking uses S3 native locking (use_lockfile) — no DynamoDB required
# with Terraform >= 1.11.

terraform {
  backend "s3" {
    bucket       = "k8s-lab-tfstate-056793557731-us-east-1"
    key          = "k8s-lab/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
