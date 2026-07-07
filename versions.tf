terraform {
  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "= 19.1.0"
    }
  }
  required_version = ">= 1.8.0"
}
