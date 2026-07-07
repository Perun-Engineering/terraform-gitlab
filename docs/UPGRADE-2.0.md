# Upgrade to 2.x

This update bumps the GitLab provider requirement from `18.4.1` to `19.1.0` to pick up
GitLab 19.0 support. The provider's own [19.0 upgrade guide](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/guides/version-19.0-upgrade)
required matching changes in this module.

Requires Terraform `>= 1.8` (needed for the `moved` blocks in `moved.tf`, which move
resources across different resource types).

## Resource renames (handled automatically by `moved.tf`)

- `gitlab_project_mirror` -> `gitlab_project_push_mirror`
- `gitlab_integration_emails_on_push` -> `gitlab_project_integration_emails_on_push`
- `gitlab_integration_external_wiki` -> `gitlab_project_integration_external_wiki`
- `gitlab_integration_github` -> `gitlab_project_integration_github`
- `gitlab_integration_jira` -> `gitlab_project_integration_jira`
- `gitlab_integration_microsoft_teams` -> `gitlab_project_integration_microsoft_teams`
- `gitlab_integration_pipelines_email` -> `gitlab_project_integration_pipelines_email`

No action needed for these; `terraform plan` will show them moved in place.

## Resource splits (require a manual `terraform state mv`)

Terraform rejects two `moved` blocks that share the same `from` address with
`Error: Ambiguous move statements`, even when the destination `for_each` sets are
disjoint — so these two splits can't be automated in `moved.tf`. Without a manual
move, `terraform plan` will destroy the old resource and create the new one.

### `gitlab_deploy_token` -> `gitlab_project_deploy_token` / `gitlab_group_deploy_token`

Move each instance to the resource matching its scope (`project` vs `group` in your
`gitlab_deploy_token.this` addresses):

```bash
terraform state mv 'module.gitlab.gitlab_deploy_token.this["project-ns-proj-mytoken"]' 'module.gitlab.gitlab_project_deploy_token.this["project-ns-proj-mytoken"]'
terraform state mv 'module.gitlab.gitlab_deploy_token.this["group-mygroup-mytoken"]'   'module.gitlab.gitlab_group_deploy_token.this["group-mygroup-mytoken"]'
```

### `gitlab_branch_protection` -> `.ce` / `.ee`

Move each instance to `.ce` if your `var.tier` is `free`, or `.ee` if `premium`/`ultimate`:

```bash
# tier = "free"
terraform state mv 'module.gitlab.gitlab_branch_protection.this["ns-proj-main"]' 'module.gitlab.gitlab_branch_protection.ce["ns-proj-main"]'

# tier = "premium" / "ultimate"
terraform state mv 'module.gitlab.gitlab_branch_protection.this["ns-proj-main"]' 'module.gitlab.gitlab_branch_protection.ee["ns-proj-main"]'
```

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
