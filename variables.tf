
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
