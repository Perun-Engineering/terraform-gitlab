# Unit tests for protected tags and the job token push setting of projects. They use a mock provider and do not call GitLab.

mock_provider "gitlab" {
  # Some arguments take a project ID or a deploy key ID as a number. A random mock ID is not a number.
  mock_resource "gitlab_project" {
    defaults = { id = "1" }
  }
  mock_resource "gitlab_deploy_key" {
    defaults = { id = "1:42", deploy_key_id = 42 }
  }
  mock_data "gitlab_project" {
    defaults = { id = "1" }
  }
  mock_resource "gitlab_group" {
    defaults = { id = "1" }
  }
}

variables {
  gitlab_groups = [
    { name = "alpha", create = true, settings = {} },
  ]
  gitlab_projects = [
    {
      name                                     = "app"
      namespace                                = "alpha"
      create                                   = true
      ci_push_repository_for_job_token_allowed = true
      settings = {
        deploy_keys = [
          { title = "TAGGER", key = "ssh-ed25519 AAAA-test-key", can_push = true },
        ]
        protected_tags = [
          { tag = "v*", allowed_to_create = [{ deploy_key_title = "TAGGER" }] },
          { tag = "rc-*", create_access_level = "no one" },
        ]
      }
    },
    {
      name      = "plain"
      namespace = "alpha"
      create    = true
      settings  = {}
    },
  ]
}

run "protected_tag_gives_create_access_to_the_deploy_key" {
  command = plan

  assert {
    condition     = gitlab_tag_protection.this["alpha-app-v*"].tag == "v*"
    error_message = "Each protected_tags entry must create one gitlab_tag_protection."
  }

  assert {
    condition     = gitlab_tag_protection.this["alpha-app-v*"].create_access_level == "maintainer"
    error_message = "A protected tag without create_access_level must default to maintainer."
  }

  assert {
    condition     = length(gitlab_tag_protection.this) == 2
    error_message = "Only the protected_tags entries must create tag protections."
  }
}

run "protected_tag_resolves_the_deploy_key_id" {
  assert {
    condition     = one(gitlab_tag_protection.this["alpha-app-v*"].allowed_to_create).deploy_key_id == 42
    error_message = "deploy_key_title must resolve to the ID of the project deploy key."
  }

  assert {
    condition     = gitlab_tag_protection.this["alpha-app-rc-*"].create_access_level == "no one"
    error_message = "create_access_level must pass through."
  }
}

run "job_token_push_is_set_only_where_configured" {
  command = plan

  assert {
    condition     = gitlab_project.this["alpha/app"].ci_push_repository_for_job_token_allowed == true
    error_message = "ci_push_repository_for_job_token_allowed must pass through to gitlab_project."
  }
}

run "unknown_deploy_key_title_fails" {
  command = plan

  variables {
    gitlab_projects = [
      {
        name      = "app"
        namespace = "alpha"
        create    = true
        settings = {
          protected_tags = [
            { tag = "v*", allowed_to_create = [{ deploy_key_title = "MISSING" }] },
          ]
        }
      },
    ]
  }

  expect_failures = [gitlab_tag_protection.this]
}
