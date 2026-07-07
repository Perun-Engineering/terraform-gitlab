locals {
  # iam_role     = "arn:aws:iam::012345678912:role/terragrunt"
  # session_name = "gitlab-terragrunt-012345678912"
  # Modules version (sorted a-z)
  terraform-gitlab = "v1.4.0" # https://github.com/Perun-Engineering/terraform-gitlab
}

terraform_version_constraint  = ">= 1.8.0"
terragrunt_version_constraint = "= 0.99.5"
# iam_role                      = local.iam_role

# Configure Terragrunt to automatically store tfstate files in an S3 bucket
#remote_state {
#  backend = "s3"
#  config = {
#    encrypt        = true
#    bucket         = "gitlab-terraform-state"
#    key            = "${path_relative_to_include()}/terraform.tfstate"
#    region         = local.aws_region
#    dynamodb_table = "terraform-locks"
#  }
#  generate = {
#    path      = "backend.tf"
#    if_exists = "overwrite_terragrunt"
#  }
#}
