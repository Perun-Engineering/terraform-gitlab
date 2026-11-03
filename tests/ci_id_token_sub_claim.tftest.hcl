# Unit tests for the ID token sub claim components of projects. They use a mock provider and do not call GitLab.
# The runs use apply, not plan. The attribute is computed, so plan shows an unset value as unknown.

mock_provider "gitlab" {
  # Some arguments take a project ID as a number. A random mock ID is not a number.
  # The mock components are a sentinel. A project that does not set the components must keep it.
  # If the module sets a value, the sentinel changes. This is also true for the GitLab default value.
  mock_resource "gitlab_project" {
    defaults = {
      id                               = "1"
      ci_id_token_sub_claim_components = ["mock_default"]
    }
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
      name                             = "custom"
      namespace                        = "alpha"
      create                           = true
      ci_id_token_sub_claim_components = ["project_path", "ref_type", "ref", "environment_protected", "deployment_tier"]
      settings                         = {}
    },
    {
      name      = "default"
      namespace = "alpha"
      create    = true
      settings  = {}
    },
  ]
}

run "project_with_components_sets_the_list" {
  assert {
    condition     = gitlab_project.this["alpha/custom"].ci_id_token_sub_claim_components == tolist(["project_path", "ref_type", "ref", "environment_protected", "deployment_tier"])
    error_message = "A project with ci_id_token_sub_claim_components must set the list on gitlab_project."
  }
}

run "project_without_components_does_not_set_the_attribute" {
  assert {
    condition     = gitlab_project.this["alpha/default"].ci_id_token_sub_claim_components == tolist(["mock_default"])
    error_message = "A project without ci_id_token_sub_claim_components must not set the attribute."
  }
}
