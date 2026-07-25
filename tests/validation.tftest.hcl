# Requires Terraform >= 1.7 (or OpenTofu >= 1.7) for `mock_provider`. This is a
# test-only requirement: the module itself still supports Terraform >= 1.5, so
# versions.tf is deliberately not bumped for it.

mock_provider "google" {}

variables {
  project_id         = "example-project"
  name               = "test-mig"
  zone               = "us-central1-a"
  base_instance_name = "test"
  instance_template  = "projects/example-project/global/instanceTemplates/test"
}

run "rejects_proactive_rollout_without_a_health_signal" {
  command = plan

  variables {
    update_policy = {
      type           = "PROACTIVE"
      minimal_action = "REPLACE"
    }
  }

  expect_failures = [google_compute_instance_group_manager.this]
}

run "rejects_a_rollout_that_can_never_make_progress" {
  command = plan

  variables {
    auto_healing_policy = {
      health_check = "projects/example-project/global/healthChecks/test"
    }
    update_policy = {
      type                  = "PROACTIVE"
      minimal_action        = "REPLACE"
      max_surge_fixed       = 0
      max_unavailable_fixed = 0
    }
  }

  expect_failures = [google_compute_instance_group_manager.this]
}

run "rejects_unknown_update_policy_type" {
  command = plan

  variables {
    update_policy = {
      type           = "AUTOMATIC"
      minimal_action = "REPLACE"
    }
  }

  expect_failures = [var.update_policy]
}

run "rejects_unknown_minimal_action" {
  command = plan

  variables {
    update_policy = {
      type           = "OPPORTUNISTIC"
      minimal_action = "RECREATE"
    }
  }

  expect_failures = [var.update_policy]
}

run "rejects_ceiling_below_minimal_action" {
  command = plan

  variables {
    update_policy = {
      type                           = "OPPORTUNISTIC"
      minimal_action                 = "REPLACE"
      most_disruptive_allowed_action = "REFRESH"
    }
  }

  expect_failures = [var.update_policy]
}

run "rejects_recreate_without_unavailable_headroom" {
  command = plan

  variables {
    update_policy = {
      type               = "OPPORTUNISTIC"
      minimal_action     = "REPLACE"
      replacement_method = "RECREATE"
    }
  }

  expect_failures = [var.update_policy]
}

run "rejects_conflicting_surge_settings" {
  command = plan

  variables {
    update_policy = {
      type              = "OPPORTUNISTIC"
      minimal_action    = "REPLACE"
      max_surge_fixed   = 1
      max_surge_percent = 20
    }
  }

  expect_failures = [var.update_policy]
}

run "rejects_out_of_range_surge_percent" {
  command = plan

  variables {
    update_policy = {
      type              = "OPPORTUNISTIC"
      minimal_action    = "REPLACE"
      max_surge_percent = 150
    }
  }

  expect_failures = [var.update_policy]
}

run "rejects_auto_healing_with_a_blank_health_check" {
  command = plan

  variables {
    auto_healing_policy = {
      health_check = "  "
    }
  }

  expect_failures = [var.auto_healing_policy]
}

run "rejects_initial_delay_above_the_api_limit" {
  command = plan

  variables {
    auto_healing_policy = {
      health_check      = "projects/example-project/global/healthChecks/test"
      initial_delay_sec = 3601
    }
  }

  expect_failures = [var.auto_healing_policy]
}

run "rejects_negative_initial_delay" {
  command = plan

  variables {
    auto_healing_policy = {
      health_check      = "projects/example-project/global/healthChecks/test"
      initial_delay_sec = -1
    }
  }

  expect_failures = [var.auto_healing_policy]
}

run "rejects_negative_target_size" {
  command = plan

  variables {
    target_size = -1
  }

  expect_failures = [var.target_size]
}

run "rejects_out_of_range_named_port" {
  command = plan

  variables {
    named_ports = {
      http = 70000
    }
  }

  expect_failures = [var.named_ports]
}

run "rejects_malformed_named_port_name" {
  command = plan

  variables {
    named_ports = {
      HTTP = 80
    }
  }

  expect_failures = [var.named_ports]
}
