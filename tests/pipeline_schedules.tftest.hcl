# Unit tests for the ref of pipeline schedules. They use a mock provider and do not call GitLab.

mock_provider "gitlab" {}

variables {
  gitlab_groups = []
  gitlab_projects = [
    {
      name      = "api"
      namespace = "alpha"
      create    = true
      settings = {
        pipeline_schedules = [
          { description = "nightly", ref = "main", cron = "0 1 * * *" },
          { description = "release", ref = "refs/tags/v1.0.0", cron = "0 2 * * *" },
        ]
      }
    },
  ]
}

run "short_ref_becomes_a_full_branch_ref" {
  command = plan

  assert {
    condition     = gitlab_pipeline_schedule.this["alpha-api-main-nightly"].ref == "refs/heads/main"
    error_message = "A short ref must become refs/heads/<ref>, and the key must keep the ref as written."
  }
}

run "full_ref_does_not_change" {
  command = plan

  assert {
    condition     = gitlab_pipeline_schedule.this["alpha-api-refs/tags/v1.0.0-release"].ref == "refs/tags/v1.0.0"
    error_message = "A full ref must not change."
  }
}
