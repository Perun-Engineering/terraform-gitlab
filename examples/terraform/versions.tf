terraform {
  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = ">= 19.0.0"
    }
  }
  required_version = ">= 1.8.0"
}
