
# Variables for the GitLab module

variable "gitlab_groups" {
  description = "List of GitLab groups to manage."
  type        = any

  validation {
    condition = alltrue([
      for group in var.gitlab_groups : length(distinct([
        for variable in lookup(group.settings, "variables", []) : "${variable.key}:${lookup(variable, "environment_scope", "*")}"
      ])) == length(lookup(group.settings, "variables", []))
    ])
    error_message = "Each group variable must have a unique key and environment_scope pair in its group."
  }

  validation {
    condition = alltrue([
      for group in var.gitlab_groups : length(split("/", lookup(group, "parent", ""))) <= 2
    ])
    error_message = "A group's parent can be a top-level group (\"infra\") or a subgroup (\"infra/terraform\"), not deeper."
  }

  validation {
    condition = alltrue([
      for group in var.gitlab_groups : !contains(keys(group), "parent") || length(lookup(group.settings, "service_accounts", [])) == 0
    ])
    error_message = "Group service accounts are only possible in top-level groups."
  }

  validation {
    condition = alltrue(flatten([
      for group in var.gitlab_groups : [for account in lookup(group.settings, "service_accounts", []) : lookup(account, "username", null) != null]
    ]))
    error_message = "Each group service account must have a username."
  }

  validation {
    condition = alltrue(flatten([
      for group in var.gitlab_groups : [
        for member in lookup(group.settings, "memberships", []) :
        (lookup(member, "user_id", null) != null) != (lookup(member, "service_account", null) != null)
      ]
    ]))
    error_message = "Each group membership must set user_id or service_account, not both."
  }
}

variable "gitlab_projects" {
  description = "List of GitLab projects to manage."
  type        = any

  validation {
    condition = alltrue([
      for project in var.gitlab_projects : length(distinct([
        for variable in lookup(project.settings, "variables", []) : "${variable.key}:${lookup(variable, "environment_scope", "*")}"
      ])) == length(lookup(project.settings, "variables", []))
    ])
    error_message = "Each project variable must have a unique key and environment_scope pair in its project."
  }

  validation {
    condition = alltrue(flatten([
      for project in var.gitlab_projects : [
        for member in lookup(project.settings, "memberships", []) :
        (lookup(member, "user_email", null) != null) != (lookup(member, "service_account", null) != null)
      ]
    ]))
    error_message = "Each project membership must set user_email or service_account, not both."
  }
}

variable "tier" {
  type        = string
  description = "Gitlab tier"
  default     = "free"
  validation {
    condition     = contains(["free", "premium", "ultimate"], lower(var.tier))
    error_message = "The tier value must be one of `free`, `premium`, `ultimate`."
  }
}

variable "gitlab_token" {
  description = "GitLab token for API access"
  type        = string
  default     = "xxxxx"
}

variable "gitlab_base_url" {
  description = "GitLab token for API access"
  type        = string
  default     = "https://gitlab.com/api/v4/"
}

variable "gitlab_instance_service_accounts" {
  description = "List of instance service accounts to manage. Self-managed GitLab only. The provider token must be an admin token."
  type        = any
  default     = []

  validation {
    condition     = alltrue([for account in var.gitlab_instance_service_accounts : lookup(account, "username", null) != null])
    error_message = "Each instance service account must have a username."
  }

  validation {
    condition = length(var.gitlab_instance_service_accounts) == length(distinct([
      for account in var.gitlab_instance_service_accounts : lookup(account, "username", null)
    ]))
    error_message = "Each instance service account must have a unique username."
  }
}
