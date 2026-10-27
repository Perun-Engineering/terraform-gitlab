# Unit tests for groups nested under a subgroup. They use a mock provider and do not call GitLab.

mock_provider "gitlab" {
  # The example projects use arguments that take a project ID as a number. A random mock ID is not a number.
  mock_resource "gitlab_project" {
    defaults = { id = "1" }
  }
  mock_data "gitlab_project" {
    defaults = { id = "1" }
  }
}

variables {
  gitlab_groups = [
    {
      name     = "infra"
      settings = {}
    },
    {
      name     = "terraform"
      parent   = "infra"
      settings = {}
    },
    {
      name   = "terraform-aws-modules"
      parent = "infra/terraform"
      settings = {
        share_groups = [
          { share_group_id = "infra/terraform", group_access = "maintainer" },
        ]
      }
    },
  ]
  gitlab_projects = [
    {
      name      = "terraform-aws-vpc"
      namespace = "infra/terraform/terraform-aws-modules"
      settings  = {}
    },
  ]
}

run "subgroup_of_a_top_level_group_stays_in_subgroups" {
  command = plan

  assert {
    condition     = keys(gitlab_group.subgroups) == ["infra/terraform"]
    error_message = "A group whose parent is a top-level group must stay in gitlab_group.subgroups, so its address does not change."
  }
}

run "subgroup_of_a_subgroup_goes_to_nested_subgroups" {
  command = plan

  assert {
    condition     = keys(gitlab_group.nested_subgroups) == ["infra/terraform/terraform-aws-modules"]
    error_message = "A group whose parent is a subgroup must be created in gitlab_group.nested_subgroups."
  }
}

run "nested_subgroup_works_as_share_target_and_project_namespace" {
  command = plan

  assert {
    condition     = contains(keys(gitlab_group_share_group.this), "infra/terraform/terraform-aws-modules-infra/terraform")
    error_message = "A nested subgroup must resolve in share_groups."
  }

  assert {
    condition     = contains(keys(gitlab_project.this), "infra/terraform/terraform-aws-modules/terraform-aws-vpc")
    error_message = "A project must be able to live in a nested subgroup."
  }
}

run "parent_deeper_than_a_subgroup_is_rejected" {
  command = plan

  variables {
    gitlab_groups = [
      {
        name     = "too-deep"
        parent   = "a/b/c"
        settings = {}
      },
    ]
    gitlab_projects = []
  }

  expect_failures = [var.gitlab_groups]
}

run "example_creates_nested_subgroup_and_its_project" {
  command = plan

  variables {
    gitlab_groups = concat(
      yamldecode(file("examples/terraform/groups/alpha.yaml")).groups,
      yamldecode(file("examples/terraform/groups/infra.yaml")).groups,
      yamldecode(file("examples/terraform/groups/roles.yaml")).groups,
    )
    gitlab_projects = concat(
      yamldecode(file("examples/terraform/projects/alpha_projects.yaml")).projects,
      yamldecode(file("examples/terraform/projects/infra_projects.yaml")).projects,
    )
  }

  assert {
    condition     = contains(keys(gitlab_group.nested_subgroups), "infra/terraform/terraform-aws-modules")
    error_message = "The example must create the nested subgroup infra/terraform/terraform-aws-modules."
  }

  assert {
    condition     = gitlab_group.nested_subgroups["infra/terraform/terraform-aws-modules"].visibility_level == "internal"
    error_message = "The nested subgroup must get the settings of its group entry."
  }

  assert {
    condition     = contains(keys(gitlab_project.this), "infra/terraform/terraform-aws-modules/terraform-aws-vpc")
    error_message = "The example must create a project in the nested subgroup."
  }

  assert {
    condition     = contains(keys(gitlab_group_share_group.this), "infra/terraform-roles/project-sre-dev")
    error_message = "The example must share infra/terraform with roles/project-sre-dev."
  }
}
