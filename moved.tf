# State migration for the GitLab provider v19.0 upgrade.
# See docs/UPGRADE-2.0.md and the provider's upgrade guide:
# https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/guides/version-19.0-upgrade
#
# Requires Terraform >= 1.8 for moved blocks across different resource types.

moved {
  from = gitlab_project_mirror.this
  to   = gitlab_project_push_mirror.this
}

moved {
  from = gitlab_integration_emails_on_push.this
  to   = gitlab_project_integration_emails_on_push.this
}

moved {
  from = gitlab_integration_external_wiki.this
  to   = gitlab_project_integration_external_wiki.this
}

moved {
  from = gitlab_integration_github.this
  to   = gitlab_project_integration_github.this
}

moved {
  from = gitlab_integration_jira.this
  to   = gitlab_project_integration_jira.this
}

moved {
  from = gitlab_integration_microsoft_teams.this
  to   = gitlab_project_integration_microsoft_teams.this
}

moved {
  from = gitlab_integration_pipelines_email.this
  to   = gitlab_project_integration_pipelines_email.this
}

# gitlab_deploy_token (split into project/group) and gitlab_branch_protection
# (split into ce/ee) are NOT covered here: Terraform rejects two moved blocks
# sharing the same "from" with "Error: Ambiguous move statements", even when
# the destination for_each sets are disjoint. See docs/UPGRADE-2.0.md for the
# manual `terraform state mv` commands required for those two resources.
