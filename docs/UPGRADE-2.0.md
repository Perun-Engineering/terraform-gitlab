# Upgrade to 2.x

This update bumps the GitLab provider requirement from `18.4.1` to `19.1.0` to pick up
GitLab 19.0 support. The provider's own [19.0 upgrade guide](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/guides/version-19.0-upgrade)
required matching changes in this module. `moved.tf` handles the resource-type renames
automatically; no manual `terraform state mv` is required, but a plan should be reviewed
before applying since several resources are recreated under new addresses.

Requires Terraform `>= 1.8` (needed for `moved` blocks across different resource types).

## Resource renames (handled by `moved.tf`)

- `gitlab_project_mirror` -> `gitlab_project_push_mirror`
- `gitlab_integration_emails_on_push` -> `gitlab_project_integration_emails_on_push`
- `gitlab_integration_external_wiki` -> `gitlab_project_integration_external_wiki`
- `gitlab_integration_github` -> `gitlab_project_integration_github`
- `gitlab_integration_jira` -> `gitlab_project_integration_jira`
- `gitlab_integration_microsoft_teams` -> `gitlab_project_integration_microsoft_teams`
- `gitlab_integration_pipelines_email` -> `gitlab_project_integration_pipelines_email`
- `gitlab_deploy_token` split into `gitlab_project_deploy_token` and `gitlab_group_deploy_token`
- `gitlab_branch_protection` split into `gitlab_branch_protection.ce` and `gitlab_branch_protection.ee`,
  selected automatically by `var.tier`

## ⚠️ Breaking changes to `gitlab_projects` input

The following keys on a project entry no longer have any effect, because the provider
removed the underlying attributes. Use the replacement listed instead:

| Removed key | Replacement |
|---|---|
| `issues_enabled` | `issues_access_level` (`"enabled"` / `"disabled"`) |
| `merge_requests_enabled` | `merge_requests_access_level` |
| `wiki_enabled` | `wiki_access_level` |
| `snippets_enabled` | `snippets_access_level` |
| `restrict_user_defined_variables` | `ci_pipeline_variables_minimum_override_role` (`false` -> `"developer"`, `true` -> `"maintainer"`) |
| `tags` | `topics` |
| `import_url`, `import_url_username`, `import_url_password`, `mirror_trigger_builds`, `only_mirror_protected_branches`, `mirror_overwrites_diverged_branches` | still supported, but now provisioned via a new `gitlab_project_pull_mirror` resource instead of `gitlab_project` attributes. Set `mirror: true` and `import_url` on the project as before. |

## `gitlab_branch_protection` (CE vs EE)

The provider no longer allows `push_access_level`/`merge_access_level`/`unprotect_access_level`
and `allowed_to_push`/`allowed_to_merge`/`allowed_to_unprotect` on the same resource. This module
now picks the correct resource automatically based on `var.tier`:

- `tier = "free"` -> CE resource, honors `push_access_level` / `merge_access_level` on a branch.
- `tier = "premium"` / `"ultimate"` -> EE resource, honors `allowed_to_push` / `allowed_to_merge` /
  `allowed_to_unprotect` / `code_owner_approval_required` on a branch. `unprotect_access_level` is
  no longer configurable in either mode (removed by the provider).

## `gitlab_project_protected_environment`

`deploy_access_levels` blocks were replaced by a single `deploy_access_levels_attribute` list.
No input schema changes; `project.settings.protected_environments[].deploy_access_levels` is
unchanged.
