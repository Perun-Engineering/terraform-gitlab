# Unit tests for the for_each keys of CI variables. They use a mock provider and do not call GitLab.

mock_provider "gitlab" {
  # Some arguments take a project ID as a number. A random mock ID is not a number.
  mock_resource "gitlab_project" {
    defaults = { id = "1" }
  }
  mock_data "gitlab_project" {
    defaults = { id = "1" }
  }
}

variables {
  gitlab_groups = [
    {
      name   = "alpha"
      create = true
      settings = {
        variables = [
          { key = "UNIQUE", value = "a" },
          { key = "ROLE", value = "uat", environment_scope = "uat" },
          { key = "ROLE", value = "prod", environment_scope = "production" },
        ]
      }
    },
  ]
  gitlab_projects = [
    {
      name      = "api"
      namespace = "alpha"
      create    = true
      settings = {
        variables = [
          { key = "UNIQUE", value = "a", environment_scope = "uat" },
          { key = "SPLIT", value = "plain", environment_scope = "uat" },
          { key = "SPLIT", value = "secret-value", environment_scope = "production", masked = true },
          { key = "BUCKET", value = "uat", environment_scope = "uat" },
          { key = "BUCKET", value = "prod", environment_scope = "production" },
          { key = "TOKEN", value = "secret-uat", environment_scope = "uat", masked = true },
          { key = "TOKEN", value = "secret-prod", environment_scope = "production", masked = true },
        ]
      }
    },
  ]
}

run "unique_keys_keep_the_old_address" {
  command = plan

  assert {
    condition     = contains(keys(gitlab_project_variable.this), "alpha-api-UNIQUE")
    error_message = "A unique key with a non-* scope must keep the address without the scope."
  }

  assert {
    condition     = contains(keys(gitlab_group_variable.this), "alpha-UNIQUE")
    error_message = "A unique group key must keep the address without the scope."
  }

  assert {
    condition = (
      contains(keys(gitlab_project_variable.this), "alpha-api-SPLIT") &&
      contains(keys(gitlab_project_variable.this_sensitive), "alpha-api-SPLIT")
    )
    error_message = "A key that is unique in each resource must keep the address without the scope."
  }
}

run "repeated_keys_get_the_scope" {
  command = plan

  assert {
    condition = toset(keys(gitlab_project_variable.this)) == toset([
      "alpha-api-UNIQUE", "alpha-api-SPLIT", "alpha-api-BUCKET:uat", "alpha-api-BUCKET:production",
    ])
    error_message = "Repeated unmasked project keys must get the scope suffix."
  }

  assert {
    condition = toset(keys(gitlab_project_variable.this_sensitive)) == toset([
      "alpha-api-SPLIT", "alpha-api-TOKEN:uat", "alpha-api-TOKEN:production",
    ])
    error_message = "Repeated masked project keys must get the scope suffix."
  }

  assert {
    condition = toset(keys(gitlab_group_variable.this)) == toset([
      "alpha-UNIQUE", "alpha-ROLE:uat", "alpha-ROLE:production",
    ])
    error_message = "Repeated group keys must get the scope suffix."
  }

  assert {
    condition     = gitlab_project_variable.this["alpha-api-BUCKET:production"].environment_scope == "production"
    error_message = "The scoped resource must use its environment_scope."
  }
}

run "duplicate_project_key_and_scope_fails" {
  command = plan

  variables {
    gitlab_projects = [
      {
        name      = "api"
        namespace = "alpha"
        create    = true
        settings = {
          variables = [
            { key = "DUP", value = "plain", environment_scope = "uat" },
            { key = "DUP", value = "secret-value", environment_scope = "uat", masked = true },
          ]
        }
      },
    ]
  }

  expect_failures = [var.gitlab_projects]
}

run "duplicate_group_key_and_default_scope_fails" {
  command = plan

  variables {
    gitlab_groups = [
      {
        name     = "alpha"
        create   = true
        settings = { variables = [{ key = "DUP", value = "a" }, { key = "DUP", value = "b", environment_scope = "*" }] }
      },
    ]
  }

  expect_failures = [var.gitlab_groups]
}

run "example_creates_both_scoped_variables" {
  command = plan

  variables {
    gitlab_groups = concat(
      yamldecode(file("examples/terraform/groups/alpha.yaml")).groups,
      yamldecode(file("examples/terraform/groups/roles.yaml")).groups,
    )
    gitlab_projects = yamldecode(file("examples/terraform/projects/alpha_projects.yaml")).projects
  }

  assert {
    condition = alltrue([
      for key in ["alpha-project-beta-DEPLOY_ROLE_ARN:uat", "alpha-project-beta-DEPLOY_ROLE_ARN:production"] :
      contains(keys(gitlab_project_variable.this), key)
    ])
    error_message = "The example must create both scoped variables."
  }

  assert {
    condition     = contains(keys(gitlab_project_variable.this), "alpha-project-alpha-VAR1")
    error_message = "The unique key of the example must keep the address without the scope."
  }
}
