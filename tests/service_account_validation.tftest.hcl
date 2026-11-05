# Unit tests for the input checks of service accounts. They use a mock provider and do not call GitLab.

mock_provider "gitlab" {
  mock_resource "gitlab_group" {
    defaults = { id = "10" }
  }
  mock_resource "gitlab_instance_service_account" {
    defaults = { service_account_id = "21" }
  }
  mock_resource "gitlab_group_service_account" {
    defaults = { service_account_id = "22" }
  }
}

variables {
  tier                             = "premium"
  gitlab_instance_service_accounts = [{ username = "sonarqube-bot" }]
  gitlab_groups                    = [{ name = "dev", settings = {} }]
  gitlab_projects                  = []
}

run "free_tier_fails" {
  command = plan

  variables {
    tier = "free"
  }

  expect_failures = [gitlab_instance_service_account.this]
}

run "service_account_on_subgroup_fails" {
  command = plan

  variables {
    gitlab_groups = [
      { name = "dev", settings = {} },
      { name = "team", parent = "dev", settings = { service_accounts = [{ username = "team-bot" }] } },
    ]
  }

  expect_failures = [var.gitlab_groups]
}

run "service_account_without_username_fails" {
  command = plan

  variables {
    gitlab_instance_service_accounts = [{ name = "SonarQube" }]
  }

  expect_failures = [var.gitlab_instance_service_accounts]
}

run "duplicate_instance_username_fails" {
  command = plan

  variables {
    gitlab_instance_service_accounts = [{ username = "sonarqube-bot" }, { username = "sonarqube-bot" }]
  }

  expect_failures = [var.gitlab_instance_service_accounts]
}

run "same_username_for_instance_and_group_account_fails" {
  command = plan

  variables {
    gitlab_groups = [{ name = "dev", settings = { service_accounts = [{ username = "sonarqube-bot" }] } }]
  }

  expect_failures = [gitlab_instance_service_account.this, gitlab_group_service_account.this]
}

run "membership_with_user_id_and_service_account_fails" {
  command = plan

  variables {
    gitlab_groups = [
      { name = "dev", settings = { memberships = [{ user_id = "alice", service_account = "sonarqube-bot", access_level = "reporter" }] } },
    ]
  }

  expect_failures = [var.gitlab_groups]
}

run "project_membership_without_member_fails" {
  command = plan

  variables {
    gitlab_projects = [
      { name = "api", namespace = "dev", settings = { memberships = [{ access_level = "reporter" }] } },
    ]
  }

  expect_failures = [var.gitlab_projects]
}

run "membership_with_unknown_service_account_fails" {
  command = plan

  variables {
    gitlab_groups = [
      { name = "dev", settings = { memberships = [{ service_account = "missing-bot", access_level = "reporter" }] } },
    ]
  }

  expect_failures = [gitlab_group_membership.this]
}

run "instance_token_variable_without_variable_group_fails" {
  command = plan

  variables {
    gitlab_instance_service_accounts = [
      { username = "sonarqube-bot", access_tokens = [{ name = "mr", scopes = ["api"], expires_at = "2027-01-01", variable_name = "SONAR_TOKEN" }] },
    ]
  }

  expect_failures = [gitlab_group_variable.service_account_token]
}

run "token_variable_in_unmanaged_group_fails" {
  command = plan

  variables {
    gitlab_instance_service_accounts = [
      { username = "sonarqube-bot", access_tokens = [{ name = "mr", scopes = ["api"], expires_at = "2027-01-01", variable_name = "SONAR_TOKEN", variable_group = "other" }] },
    ]
  }

  expect_failures = [gitlab_group_variable.service_account_token]
}
