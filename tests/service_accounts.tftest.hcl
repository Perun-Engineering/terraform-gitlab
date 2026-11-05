# Unit tests for service accounts. They use a mock provider and do not call GitLab.

mock_provider "gitlab" {
  # Some arguments take a user ID or group ID as a number. A random mock ID is not a number.
  mock_resource "gitlab_group" {
    defaults = { id = "10" }
  }
  mock_resource "gitlab_instance_service_account" {
    defaults = { service_account_id = "21" }
  }
  mock_resource "gitlab_group_service_account" {
    defaults = { service_account_id = "22" }
  }
  mock_resource "gitlab_project" {
    defaults = { id = "1" }
  }
}

variables {
  tier = "premium"
  gitlab_instance_service_accounts = [
    {
      name     = "SonarQube"
      username = "sonarqube-bot"
      timeouts = { delete = "15m" }
    },
  ]
  gitlab_groups = [
    {
      name = "dev"
      settings = {
        service_accounts = [
          { name = "Deployer", username = "dev-deployer", skip_wait_for_deletion = true },
        ]
      }
    },
  ]
  gitlab_projects = []
}

run "instance_service_account_uses_the_input" {
  command = plan

  assert {
    condition = (
      gitlab_instance_service_account.this["sonarqube-bot"].name == "SonarQube" &&
      gitlab_instance_service_account.this["sonarqube-bot"].timeouts.delete == "15m"
    )
    error_message = "An instance service account must use name, username, and timeouts from the input."
  }
}

run "group_service_account_is_in_its_group" {
  command = apply

  assert {
    condition = (
      gitlab_group_service_account.this["dev-deployer"].group == "10" &&
      gitlab_group_service_account.this["dev-deployer"].name == "Deployer" &&
      gitlab_group_service_account.this["dev-deployer"].skip_wait_for_deletion
    )
    error_message = "A group service account must be in its top-level group and use the input settings."
  }
}

run "outputs_show_ids_and_usernames" {
  command = apply

  assert {
    condition = output.service_accounts == {
      "sonarqube-bot" = { id = "21", username = "sonarqube-bot" }
      "dev-deployer"  = { id = "22", username = "dev-deployer" }
    }
    error_message = "The service_accounts output must show the ID and username of each account."
  }
}

run "token_uses_rotation_configuration_without_expires_at" {
  command = plan

  variables {
    gitlab_instance_service_accounts = [
      {
        username = "sonarqube-bot"
        access_tokens = [
          {
            name                   = "mr-decoration"
            scopes                 = ["api"]
            rotation_configuration = { expiration_days = 365, rotate_before_days = 30 }
            variable_name          = "SONAR_TOKEN"
            variable_group         = "dev"
          },
        ]
      },
    ]
  }

  assert {
    condition = (
      gitlab_personal_access_token.service_account["sonarqube-bot-mr-decoration"].user_id == 21 &&
      gitlab_personal_access_token.service_account["sonarqube-bot-mr-decoration"].rotation_configuration.expiration_days == 365 &&
      gitlab_personal_access_token.service_account["sonarqube-bot-mr-decoration"].rotation_configuration.rotate_before_days == 30
    )
    error_message = "An instance service account token must use rotation_configuration. The input has no expires_at."
  }

  assert {
    condition = (
      gitlab_group_variable.service_account_token["sonarqube-bot-mr-decoration"].key == "SONAR_TOKEN" &&
      gitlab_group_variable.service_account_token["sonarqube-bot-mr-decoration"].group == "10" &&
      gitlab_group_variable.service_account_token["sonarqube-bot-mr-decoration"].protected &&
      gitlab_group_variable.service_account_token["sonarqube-bot-mr-decoration"].masked &&
      gitlab_group_variable.service_account_token["sonarqube-bot-mr-decoration"].hidden &&
      gitlab_group_variable.service_account_token["sonarqube-bot-mr-decoration"].environment_scope == "*"
    )
    error_message = "A token variable must be in variable_group, and protected, masked, and hidden by default."
  }
}

run "group_token_uses_expires_at_and_its_group_for_the_variable" {
  command = plan

  variables {
    gitlab_groups = [
      {
        name = "dev"
        settings = {
          service_accounts = [
            {
              username = "dev-deployer"
              access_tokens = [
                { name = "ci", scopes = ["read_api"], expires_at = "2027-01-01", variable_name = "DEPLOY_TOKEN", masked = false, environment_scope = "prod" },
                { name = "novar", scopes = ["read_api"], expires_at = "2027-01-01" },
              ]
            },
          ]
        }
      },
    ]
  }

  assert {
    condition = (
      gitlab_group_service_account_access_token.this["dev-deployer-ci"].group == "10" &&
      gitlab_group_service_account_access_token.this["dev-deployer-ci"].user_id == 22 &&
      gitlab_group_service_account_access_token.this["dev-deployer-ci"].expires_at == "2027-01-01" &&
      gitlab_group_service_account_access_token.this["dev-deployer-ci"].rotation_configuration == null
    )
    error_message = "A group service account token must be in the account group and use expires_at."
  }

  assert {
    condition = (
      gitlab_group_variable.service_account_token["dev-deployer-ci"].group == "10" &&
      !gitlab_group_variable.service_account_token["dev-deployer-ci"].masked &&
      !gitlab_group_variable.service_account_token["dev-deployer-ci"].hidden &&
      gitlab_group_variable.service_account_token["dev-deployer-ci"].environment_scope == "prod"
    )
    error_message = "A group token variable must be in the account group. An unmasked variable must not be hidden."
  }

  assert {
    condition     = !contains(keys(gitlab_group_variable.service_account_token), "dev-deployer-novar")
    error_message = "A token without variable_name must not create a variable."
  }
}

run "token_output_is_sensitive_and_has_each_token" {
  command = apply

  variables {
    gitlab_instance_service_accounts = [
      { username = "sonarqube-bot", access_tokens = [{ name = "mr", scopes = ["api"], expires_at = "2027-01-01" }] },
    ]
  }

  assert {
    condition     = issensitive(output.service_account_tokens) && keys(nonsensitive(output.service_account_tokens)) == ["sonarqube-bot-mr"]
    error_message = "The service_account_tokens output must be sensitive and have one entry for each token."
  }
}

run "group_token_with_rotation_uses_the_rotating_resource" {
  command = plan

  variables {
    gitlab_groups = [
      {
        name = "dev"
        settings = {
          service_accounts = [
            {
              username      = "dev-deployer"
              access_tokens = [{ name = "ci", scopes = ["api"], rotation_configuration = { expiration_days = 90, rotate_before_days = 7 } }]
            },
          ]
        }
      },
    ]
  }

  assert {
    condition = (
      !contains(keys(gitlab_group_service_account_access_token.this), "dev-deployer-ci") &&
      gitlab_group_service_account_access_token.rotating["dev-deployer-ci"].rotation_configuration.expiration_days == 90 &&
      gitlab_group_service_account_access_token.rotating["dev-deployer-ci"].rotation_configuration.rotate_before_days == 7
    )
    error_message = "A group token with rotation_configuration must use the rotating resource."
  }
}

run "memberships_use_the_service_account_id" {
  command = plan

  variables {
    gitlab_groups = [
      {
        name = "dev"
        settings = {
          service_accounts = [{ username = "dev-deployer" }]
          memberships = [
            { service_account = "sonarqube-bot", access_level = "reporter" },
            { service_account = "dev-deployer", access_level = "developer" },
          ]
        }
      },
    ]
    gitlab_projects = [
      {
        name      = "api"
        namespace = "dev"
        settings = {
          memberships = [{ service_account = "sonarqube-bot", access_level = "reporter" }]
        }
      },
    ]
  }

  assert {
    condition = (
      gitlab_group_membership.this["dev-sonarqube-bot"].user_id == 21 &&
      gitlab_group_membership.this["dev-sonarqube-bot"].access_level == "reporter" &&
      gitlab_group_membership.this["dev-dev-deployer"].user_id == 22 &&
      gitlab_project_membership.this["dev-api-sonarqube-bot"].user_id == 21
    )
    error_message = "A membership with service_account must use the ID of the service account from this run."
  }

  assert {
    condition     = length(data.gitlab_user.membership_user) == 0
    error_message = "A membership with service_account must not look up the user with a data source."
  }
}

run "token_without_expiry_is_possible" {
  command = plan

  variables {
    gitlab_instance_service_accounts = [
      { username = "sonarqube-bot", access_tokens = [{ name = "mr", scopes = ["api"] }] },
    ]
    gitlab_groups = [
      { name = "dev", settings = { service_accounts = [{ username = "dev-deployer", access_tokens = [{ name = "ci", scopes = ["api"] }] }] } },
    ]
  }

  assert {
    condition = (
      gitlab_personal_access_token.service_account["sonarqube-bot-mr"].rotation_configuration == null &&
      contains(keys(gitlab_group_service_account_access_token.this), "dev-deployer-ci")
    )
    error_message = "A token without expires_at and rotation_configuration must use the provider default."
  }
}
