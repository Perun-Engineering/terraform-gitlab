
# Service accounts. They need the Premium or Ultimate tier.
# Instance service accounts need an admin token. Group service accounts need the Owner role on the group.
# The module keys each service account by its username. GitLab usernames are unique on the instance.

locals {
  is_paid_tier = contains(["premium", "ultimate"], lower(var.tier))

  group_service_accounts = merge([
    for group in var.gitlab_groups : {
      for account in lookup(group.settings, "service_accounts", []) : account.username => merge(account, { group_name = group.name })
    }
  ]...)

  service_account_usernames = concat(
    [for account in var.gitlab_instance_service_accounts : account.username],
    flatten([for group in var.gitlab_groups : [for account in lookup(group.settings, "service_accounts", []) : account.username]]),
  )

  service_account_ids = merge(
    { for username, account in gitlab_instance_service_account.this : username => account.service_account_id },
    { for username, account in gitlab_group_service_account.this : username => account.service_account_id },
  )
}

resource "gitlab_instance_service_account" "this" {
  for_each = { for account in var.gitlab_instance_service_accounts : account.username => account }

  name     = lookup(each.value, "name", null)
  username = each.value.username
  email    = lookup(each.value, "email", null)
  timeouts = try({ delete = each.value.timeouts.delete }, null)

  lifecycle {
    precondition {
      condition     = local.is_paid_tier
      error_message = "Service accounts need the premium or ultimate tier. Set var.tier."
    }
    precondition {
      condition     = length(local.service_account_usernames) == length(distinct(local.service_account_usernames))
      error_message = "Each service account username must be unique in gitlab_instance_service_accounts and gitlab_groups."
    }
  }
}

resource "gitlab_group_service_account" "this" {
  for_each = local.group_service_accounts

  group                  = gitlab_group.parent_groups[each.value.group_name].id
  name                   = lookup(each.value, "name", null)
  username               = each.value.username
  email                  = lookup(each.value, "email", null)
  skip_wait_for_deletion = lookup(each.value, "skip_wait_for_deletion", null)
  timeouts               = try({ delete = each.value.timeouts.delete }, null)

  lifecycle {
    precondition {
      condition     = local.is_paid_tier
      error_message = "Service accounts need the premium or ultimate tier. Set var.tier."
    }
    precondition {
      condition     = length(local.service_account_usernames) == length(distinct(local.service_account_usernames))
      error_message = "Each service account username must be unique in gitlab_instance_service_accounts and gitlab_groups."
    }
  }
}

# Access tokens of service accounts. The for_each key is "<username>-<token name>".
# A token sets expires_at or rotation_configuration, not both. rotation_configuration has priority.
# If a token sets neither, the provider default applies.
locals {
  instance_service_account_tokens = merge([
    for account in var.gitlab_instance_service_accounts : {
      for token in lookup(account, "access_tokens", []) : "${account.username}-${token.name}" => {
        username       = account.username
        variable_group = lookup(token, "variable_group", null)
        token          = token
      }
    }
  ]...)

  group_service_account_tokens = merge([
    for username, account in local.group_service_accounts : {
      for token in lookup(account, "access_tokens", []) : "${username}-${token.name}" => {
        username       = username
        group_name     = account.group_name
        variable_group = lookup(token, "variable_group", account.group_name)
        token          = token
      }
    }
  ]...)

  service_account_token_values = merge(
    { for key, token in gitlab_personal_access_token.service_account : key => token.token },
    { for key, token in gitlab_group_service_account_access_token.this : key => token.token },
    { for key, token in gitlab_group_service_account_access_token.rotating : key => token.token },
  )
}

resource "gitlab_personal_access_token" "service_account" {
  for_each = local.instance_service_account_tokens

  user_id     = gitlab_instance_service_account.this[each.value.username].service_account_id
  name        = each.value.token.name
  description = lookup(each.value.token, "description", null)
  scopes      = each.value.token.scopes

  expires_at = contains(keys(each.value.token), "rotation_configuration") ? null : lookup(each.value.token, "expires_at", null)
  rotation_configuration = contains(keys(each.value.token), "rotation_configuration") ? {
    expiration_days    = lookup(each.value.token.rotation_configuration, "expiration_days", null)
    rotate_before_days = each.value.token.rotation_configuration.rotate_before_days
  } : null
}

# Group service account tokens use two resources: one with expires_at, one with rotation_configuration.
# Provider 19.5.0 panics in validate if rotation_configuration is unknown, for example from a conditional.
# An object literal stays known in validate, so the rotating resource always sets it.
resource "gitlab_group_service_account_access_token" "this" {
  for_each = {
    for key, entry in local.group_service_account_tokens : key => entry
    if !contains(keys(entry.token), "rotation_configuration")
  }

  group       = gitlab_group.parent_groups[each.value.group_name].id
  user_id     = gitlab_group_service_account.this[each.value.username].service_account_id
  name        = each.value.token.name
  description = lookup(each.value.token, "description", null)
  scopes      = each.value.token.scopes
  expires_at  = lookup(each.value.token, "expires_at", null)
}

resource "gitlab_group_service_account_access_token" "rotating" {
  for_each = {
    for key, entry in local.group_service_account_tokens : key => entry
    if contains(keys(entry.token), "rotation_configuration")
  }

  group       = gitlab_group.parent_groups[each.value.group_name].id
  user_id     = gitlab_group_service_account.this[each.value.username].service_account_id
  name        = each.value.token.name
  description = lookup(each.value.token, "description", null)
  scopes      = each.value.token.scopes

  rotation_configuration = {
    expiration_days    = lookup(each.value.token.rotation_configuration, "expiration_days", null)
    rotate_before_days = each.value.token.rotation_configuration.rotate_before_days
  }
}

# Save a token in a CI/CD variable of a managed group if the token sets variable_name.
# The variable is protected, masked, and hidden by default. A hidden variable must be masked.
resource "gitlab_group_variable" "service_account_token" {
  for_each = {
    for key, entry in merge(local.instance_service_account_tokens, local.group_service_account_tokens) :
    key => entry if lookup(entry.token, "variable_name", null) != null
  }

  group             = local.group_ids[each.value.variable_group]
  key               = each.value.token.variable_name
  value             = sensitive(local.service_account_token_values[each.key])
  protected         = lookup(each.value.token, "protected", true)
  masked            = lookup(each.value.token, "masked", true)
  hidden            = lookup(each.value.token, "hidden", lookup(each.value.token, "masked", true))
  environment_scope = lookup(each.value.token, "environment_scope", "*")
  description       = "Generated access token for the service account ${each.value.username}"

  lifecycle {
    precondition {
      condition     = contains(local.managed_group_paths, coalesce(each.value.variable_group, "-"))
      error_message = "A token with variable_name must set variable_group to a group that this module manages. An instance service account has no default group."
    }
  }
}
