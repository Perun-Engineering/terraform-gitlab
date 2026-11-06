# GitLab Terraform Module

This Terraform module provides resources to manage GitLab groups, projects, integrations, and other configurations. It supports creating and managing GitLab resources using a structured configuration approach with YAML files or direct variable definitions.

## Features

- Manage GitLab groups and projects.
- Configure integrations (e.g., custom issue tracker, Jira, Slack, etc.).
- Define custom project settings, approval rules, badges, and more.
- Easily extendable and customizable to fit various GitLab environments.

## Limitations

- Creation of local users is not supported at the moment, only via SAML

## Requirements

- Terraform 1.8.0 or higher.
- GitLab Provider for Terraform 19.5.0. The module pins this exact version. After you change the module version, run `terraform init -upgrade`. See [docs/UPGRADE-2.0.md](docs/UPGRADE-2.0.md) if upgrading from a 18.x-based release of this module.

## Notes

- `pipeline_schedules[*].ref` accepts a short branch name (`main`) or a full ref (`refs/heads/main`, `refs/tags/v1.0.0`). The module changes a short name to `refs/heads/<name>`. For a tag, use the full ref.
- The provider deprecated the `push_rules` block of `gitlab_project` in 19.4.1 and removes it in 20.0. The module uses this block for project `push_rules`, and the plan shows a deprecation warning.

## Usage

### Step 1: Create Your Configuration Files

1. **Groups Configuration**

   Define your GitLab groups in YAML files located in the `groups` directory. Example `groups/groups.yaml`:

   ```yaml
   groups:
     - name: alpha
       create: true
       settings:
         visibility: private
         description: "Development top-level group"
         share_groups:
           - share_group_id: "roles_test/security-view"
             group_access: reporter
     - name: roles_test
       create: true
       settings:
         visibility: private
         description: "Parent group for user roles subgroups"
   ```

2. **Projects Configuration**

   Define your GitLab projects in YAML files located in the projects directory. Example projects/projects.yaml:

   ```yaml
   projects:
   - name: project-alpha
       create: true
       visibility: private
       description: "Alpha project description"
       settings: {}
   ```

### Step 2: Use the Module

Create a main.tf file and use the module to manage your GitLab resources:

    ```hcl
    module "gitlab_resources" {
    source = "../module/gitlab_module"

    gitlab_groups   = local.groups
    gitlab_projects = local.projects
    }
    ```

### Step 3: Initialize and Apply

1. **Initialize Terraform:**

   ```sh
   terraform init
   ```

2. **Apply the Terraform configuration:**

   ```sh
   terraform apply
   ```

### Step 4: Verify Outputs

The module will output the IDs and URLs of the created resources. You can check the created GitLab resources by visiting their URLs.

## Inputs

The module accepts the following inputs:

- gitlab_groups: List of GitLab groups to create and configure.
- gitlab_projects: List of GitLab projects to create and configure.
- gitlab_token: GitLab toke
- gitlab_base_url: Url of the GitLab instance API
- tier: Tier of your GitLab license
- gitlab_instance_service_accounts: List of instance service accounts. Self-managed GitLab only.

Refer to the variables.tf file for more details.

## CI variables in many environment scopes

A group or project can have one variable key in more than one `environment_scope`.
Each key and `environment_scope` pair must be unique in its group or project. If it is not unique, the plan fails.

The module puts masked and unmasked variables in different resources (`this_sensitive` and `this`).
The `for_each` key of a variable depends on how many times its key occurs in its resource:

| Key occurs | Project key | Group key |
|---|---|---|
| Once | `<namespace>-<project>-<KEY>` | `<group path>-<KEY>` |
| More than once | `<namespace>-<project>-<KEY>:<environment_scope>` | `<group path>-<KEY>:<environment_scope>` |

Thus the addresses of current variables do not change.

**Caution:** If you add a second scope for a key that occurs once, the address of the first variable changes.
The same occurs when you remove scopes until the key occurs once.
Without a `moved` block, Terraform destroys the variable and creates it again.
Add a `moved` block in your root module before you apply:

```hcl
moved {
  from = module.gitlab.gitlab_project_variable.this["infra-api-UI_BUCKET"]
  to   = module.gitlab.gitlab_project_variable.this["infra-api-UI_BUCKET:ui-uat"]
}
```

## Access token variables

A group or project access token can put its value in a CI/CD variable. Set `variable_name` on the token to the key of the variable.
These token keys set the variable:

| Key | Default | Description |
|---|---|---|
| `variable_name` | none | The key of the variable. If it is not set, the module does not create a variable. |
| `protected` | `true` | Only pipelines on protected branches and tags get the variable. |
| `masked` | `true` | The job logs do not show the value. |
| `environment_scope` | `"*"` | The environments that get the variable. |

```yaml
access_tokens:
  - name: mr-reporter
    scopes: ["api"]
    access_level: developer
    expires_at: "2027-01-01"
    variable_name: MR_API_TOKEN
    protected: true
```

**Warning:** An unprotected variable with an `api` token is available to all pipelines on all branches. Keep `protected: true` if you do not have a strong reason.

## Service accounts

Service accounts need the `premium` or `ultimate` tier. If `tier` is `free`, the plan fails.
The module keys each service account by its `username`, so `username` is required and must be unique.

| Kind | Input | Requirements |
|---|---|---|
| Instance | `gitlab_instance_service_accounts` | Self-managed GitLab. The provider token must be an admin token. |
| Group | `gitlab_groups[].settings.service_accounts` | Top-level groups only. The provider token must have the Owner role on the group. |

Account keys:

| Key | Description |
|---|---|
| `username` | Required. The username of the account. |
| `name` | The display name. |
| `email` | The email. |
| `skip_wait_for_deletion` | Group accounts only. Do not wait until GitLab deletes the account. |
| `timeouts.delete` | The time to wait until GitLab deletes the account. |
| `access_tokens` | The tokens of the account. |

A token sets `name`, `scopes`, and `expires_at` or `rotation_configuration`. If you set both, the module uses `rotation_configuration`. If you set neither, the provider default applies.
A token can put its value in a CI/CD variable of a managed group. Set `variable_name` on the token.
The variable has the keys of [Access token variables](#access-token-variables), and these keys:

| Key | Default | Description |
|---|---|---|
| `variable_group` | The group of the account | The key of a managed group, for example `dev` or `dev/team`. Required for an instance account. |
| `hidden` | The value of `masked` | The CI/CD settings do not show the value. A hidden variable must be masked. |

A group or project membership can use a service account from the same run. Set `service_account` to its username, not `user_id` or `user_email`:

```hcl
gitlab_instance_service_accounts = [
  {
    name     = "SonarQube"
    username = "sonarqube-bot"
    access_tokens = [
      {
        name   = "mr-decoration"
        scopes = ["api"]
        rotation_configuration = {
          expiration_days    = 365
          rotate_before_days = 30
        }
        variable_name  = "SONAR_TOKEN"
        variable_group = "dev"
      }
    ]
  }
]

gitlab_groups = [
  {
    name = "dev"
    settings = {
      memberships = [
        { service_account = "sonarqube-bot", access_level = "reporter" }
      ]
    }
  }
]
```

The `service_accounts` output shows the ID and username of each account. The sensitive `service_account_tokens` output shows the token values, keyed by `<username>-<token name>`.

**Warning:** Terraform keeps the token values in the state. Keep the state in an encrypted backend with restricted access.

**Note:** Group tokens with `rotation_configuration` go to `gitlab_group_service_account_access_token.rotating`, other group tokens go to `.this`. Provider 19.5.0 crashes in `terraform validate` if `rotation_configuration` comes from a conditional expression.

## ID token sub claim

Set `ci_id_token_sub_claim_components` on a project to change the `sub` claim of the CI/CD ID tokens of its jobs.
If you do not set the key, the module does not change the claim. GitLab then uses `["project_path", "ref_type", "ref"]`.

```yaml
projects:
  - name: deployer
    namespace: infra
    ci_id_token_sub_claim_components: ["project_path", "ref_type", "ref", "environment_protected", "deployment_tier"]
```

A job in a protected environment then gets `project_path:infra/deployer:ref_type:branch:ref:main:environment_protected:true:deployment_tier:other`.

**Caution:** A cloud role that trusts an exact `sub` stops matching when you change the components. Update the trust policy of the role before you apply.

## Protected tags

Set `protected_tags` in the project settings to protect tags. `tag` is a tag name or a wildcard.

```yaml
projects:
  - name: app
    namespace: infra
    settings:
      deploy_keys:
        - title: RELEASE_KEY
          key: ssh-ed25519 AAAA...
          can_push: true
      protected_tags:
        - tag: "v*"
          create_access_level: maintainer   # default
          allowed_to_create:
            - deploy_key_title: RELEASE_KEY
```

An `allowed_to_create` entry sets one of `access_level`, `user_email`, `group` or `deploy_key_title`. A `deploy_key_title` must be the title of a deploy key of the same project, or the plan fails. A user, group or deploy key needs GitLab Premium or Ultimate.

## Job token push

Set `ci_push_repository_for_job_token_allowed: true` on a project to allow Git push requests that use the CI/CD job token. The job token has the permissions of the user who runs the job, so protected branches and tags still apply. If you do not set the key, the module does not change the setting.

## Nested subgroups

A group can be up to three levels deep: a top-level group, a subgroup, and a group in that subgroup.
For a group in a subgroup, set `parent` to the key of the subgroup, `<parent>/<name>`:

```yaml
groups:
  - name: infra
  - name: terraform
    parent: infra
  - name: terraform-aws-modules
    parent: infra/terraform   # creates infra/terraform/terraform-aws-modules
```

`parent` uses the subgroup's `name`, not its `path`. Keep `name` and `path` the same, so `parent` is also the full path of the parent group, and a project can use it as `namespace`.

Groups whose parent is a top-level group stay in `gitlab_group.subgroups`. Groups whose parent is a subgroup go to `gitlab_group.nested_subgroups`. Thus the addresses of current groups do not change.
A `parent` deeper than a subgroup (`a/b/c`) fails validation.

See [examples/terraform/groups/infra.yaml](examples/terraform/groups/infra.yaml) and [examples/terraform/projects/infra_projects.yaml](examples/terraform/projects/infra_projects.yaml).

## Outputs

The module provides the following outputs:

- group_ids: List of IDs for the created GitLab groups.
- project_ids: List of IDs for the created GitLab projects.
- Other resource-specific outputs, such as integration settings and custom configurations.

## Examples

You can find examples in the examples/ directory for different use cases, such as managing multiple groups, configuring integrations, and using different YAML configurations.

- [terraform](https://github.com/Perun-Engineering/terraform-gitlab/tree/main/examples/terraform) - How to use module with terraform
- [terragrunt](https://github.com/Perun-Engineering/terraform-gitlab/tree/main/examples/terragrunt) - How to use module with terragrunt

## Authors

Module is maintained by [Serhii Kaidalov](https://github.com/wiseelf).

## License

Apache 2 Licensed. See [LICENSE](https://github.com/Perun-Engineering/terraform-gitlab/tree/main/LICENSE) for full details.
