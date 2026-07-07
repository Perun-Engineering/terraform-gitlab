# Changelog

All notable changes to this project will be documented in this file.

## [2.0.1](https://github.com/Perun-Engineering/terraform-gitlab/compare/v2.0.0...v2.0.1) (2026-07-07)


### Bug Fixes

* Import-safety fixes for managed group lookups and gitlab_branch ([#11](https://github.com/Perun-Engineering/terraform-gitlab/issues/11)) ([0e8291b](https://github.com/Perun-Engineering/terraform-gitlab/commit/0e8291baf60db7bc262b953db0efe7ceca151cbc))

## [2.0.0](https://github.com/Perun-Engineering/terraform-gitlab/compare/v1.4.0...v2.0.0) (2026-07-07)


### ⚠ BREAKING CHANGES

* renames gitlab_project_mirror, gitlab_integration_* resources,
splits gitlab_deploy_token into project/group and gitlab_branch_protection into
CE/EE variants, and removes deprecated gitlab_project boolean/mirror attributes
per the provider's 19.0 upgrade guide. See docs/UPGRADE-2.0.md.

* fix: Bump terragrunt_version_constraint to 0.99.5 in terragrunt example

* fix: Drop ambiguous moved blocks for split resources

Terraform rejects two moved blocks sharing the same 'from' address with
'Ambiguous move statements', so the gitlab_deploy_token and
gitlab_branch_protection splits can't be automated via moved.tf. Keep the
7 safe 1:1 resource renames there, and document the required manual
terraform state mv commands for the two splits in docs/UPGRADE-2.0.md.

* fix: Forward access_level in gitlab_branch_protection ee allowed_to_* lists

allowed_to_push/allowed_to_merge/allowed_to_unprotect entries only computed
user_id/group_id/deploy_key_id, silently dropping access_level. Since EE no
longer honors push_access_level/merge_access_level at all, callers now rely
on an access_level entry inside allowed_to_push/allowed_to_merge, which the
module previously discarded, producing all-null entries and provider errors.

* fix: Replace deprecated require_password_to_approve attribute

require_password_to_approve on gitlab_project_level_mr_approvals is
deprecated in provider 19.x and removed in 20.0; use
require_reauthentication_to_approve instead.

* fix: Replace bulk gitlab_users/gitlab_groups lookups with scoped fetches

data "gitlab_users" "this" {} and data "gitlab_groups" "this" {} paged the
whole instance (720+ users here) and were non-deterministic between two reads
a minute apart, flipping which user/group resolved for allowed_to_push,
allowed_to_merge, membership, approval_rule, and protected_environment
entries and tripping the provider's ExactlyOneOf validator.

Replace both with data.gitlab_user/data.gitlab_group for_each, scoped to only
the emails and group full_paths actually referenced across
var.gitlab_projects. Groups already managed by this module invocation are
merged in directly from gitlab_group.parent_groups/subgroups rather than
looked up externally, since a brand-new group doesn't exist yet at plan time
and would otherwise 404 the data source read. exists_users/exists_groups
keep their existing shape so no other call site changes.

### Features

* Upgrade gitlab provider to 19.x ([#10](https://github.com/Perun-Engineering/terraform-gitlab/issues/10)) ([38b5a40](https://github.com/Perun-Engineering/terraform-gitlab/commit/38b5a40d1eaa7a9eeec97aea15787b28a7d7e60c))

## [1.4.0](https://github.com/Perun-Engineering/terraform-gitlab/compare/v1.3.0...v1.4.0) (2025-10-09)


### Features

* Add push support for deploy keys, bump version ([#8](https://github.com/Perun-Engineering/terraform-gitlab/issues/8)) ([119195d](https://github.com/Perun-Engineering/terraform-gitlab/commit/119195da4b27389c1eb633e493f7f0b48ed7f13e))

## [1.3.0](https://github.com/Perun-Engineering/terraform-gitlab/compare/v1.2.0...v1.3.0) (2025-08-04)


### Features

* Allow to set gitlab_project_variable properties ([3e3466a](https://github.com/Perun-Engineering/terraform-gitlab/commit/3e3466acead8b23ad887a8f9c3e3ae4de031ae8f))

## [1.2.0](https://github.com/Perun-Engineering/terraform-gitlab/compare/v1.1.0...v1.2.0) (2025-07-24)


### Features

* Mark hidden variables sensitive ([#6](https://github.com/Perun-Engineering/terraform-gitlab/issues/6)) ([c928dbf](https://github.com/Perun-Engineering/terraform-gitlab/commit/c928dbf249fd19cecb1db443579e7ed062cd8f5f))

## [1.1.0](https://github.com/Perun-Engineering/terraform-gitlab/compare/v1.0.1...v1.1.0) (2025-07-18)


### Features

* Allow to use tokens to authenticate requests from external managed projects ([#5](https://github.com/Perun-Engineering/terraform-gitlab/issues/5)) ([2d44ddd](https://github.com/Perun-Engineering/terraform-gitlab/commit/2d44ddd1667d84ceca2969cac2ddf8cd3187e194))

## [1.0.1](https://github.com/Perun-Engineering/terraform-gitlab/compare/v1.0.0...v1.0.1) (2025-05-27)


### Bug Fixes

* Do not create default branch ([eefd607](https://github.com/Perun-Engineering/terraform-gitlab/commit/eefd6071557d4f96391caac32d7eb264d1e573e9))

## 1.0.0 (2025-05-26)


### Features

* Add support for hidden variables ([3491d99](https://github.com/Perun-Engineering/terraform-gitlab/commit/3491d99f9eda691864317f0d3449c702a5cfb6ed))
