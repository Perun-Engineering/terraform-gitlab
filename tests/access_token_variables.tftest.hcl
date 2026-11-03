# Unit tests for the CI variables of access tokens. They use a mock provider and do not call GitLab.

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
        access_tokens = [
          { name = "default", scopes = ["api"], access_level = "maintainer", expires_at = "2027-01-01", variable_name = "GROUP_DEFAULT" },
          { name = "custom", scopes = ["api"], access_level = "maintainer", expires_at = "2027-01-01", variable_name = "GROUP_CUSTOM", protected = false, masked = false, environment_scope = "uat" },
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
        access_tokens = [
          { name = "default", scopes = ["api"], expires_at = "2027-01-01", variable_name = "PROJECT_DEFAULT" },
          { name = "custom", scopes = ["api"], expires_at = "2027-01-01", variable_name = "PROJECT_CUSTOM", protected = false, masked = false, environment_scope = "uat" },
          { name = "novar", scopes = ["api"], expires_at = "2027-01-01" },
        ]
      }
    },
  ]
}

run "token_variable_uses_the_defaults" {
  command = plan

  assert {
    condition = alltrue([
      for variable in [gitlab_project_variable.access_token_this["alpha-api-default"], gitlab_group_variable.access_token_this["alpha-default"]] :
      variable.protected && variable.masked && variable.environment_scope == "*"
    ])
    error_message = "A token variable without settings must be protected, masked, and in the * scope."
  }
}

run "token_variable_uses_the_token_settings" {
  command = plan

  assert {
    condition = alltrue([
      for variable in [gitlab_project_variable.access_token_this["alpha-api-custom"], gitlab_group_variable.access_token_this["alpha-custom"]] :
      !variable.protected && !variable.masked && variable.environment_scope == "uat"
    ])
    error_message = "A token variable must use protected, masked, and environment_scope from the token."
  }
}

run "token_without_variable_name_has_no_variable" {
  command = plan

  assert {
    condition     = !contains(keys(gitlab_project_variable.access_token_this), "alpha-api-novar")
    error_message = "A token without variable_name must not create a variable."
  }
}
