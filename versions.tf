terraform {
  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "= 18.4.1"
    }
  }
  required_version = ">= 1.4.0"
}
