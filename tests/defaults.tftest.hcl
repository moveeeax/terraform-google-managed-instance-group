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

run "defaults_are_conservative" {
  command = plan

  assert {
    condition     = google_compute_instance_group_manager.this.target_size == 2
    error_message = "target_size should default to 2."
  }

  assert {
    condition     = length(google_compute_instance_group_manager.this.auto_healing_policies) == 0
    error_message = "Auto-healing must stay opt-in; enabling it without a caller-supplied health check is not possible."
  }

  assert {
    condition     = length(google_compute_instance_group_manager.this.update_policy) == 0
    error_message = "No update_policy must be emitted by default, so a template change never rolls the fleet unattended."
  }

  assert {
    condition     = length(google_compute_instance_group_manager.this.named_port) == 0
    error_message = "No named ports should be declared by default."
  }
}

# target_size is optional+computed in the provider, so once it is unset its
# planned value is unknown and cannot be asserted on directly. What this run
# proves is that null is accepted at all: the module used to validate
# `target_size >= 0`, which errors out on null and forced every caller to keep
# Terraform in charge of the instance count even when an autoscaler owned it.
run "target_size_may_be_null_for_autoscaler_ownership" {
  command = plan

  variables {
    target_size = null
  }

  assert {
    condition     = google_compute_instance_group_manager.this.base_instance_name == "test"
    error_message = "The group should still plan cleanly when the instance count is left to an autoscaler."
  }
}

run "named_ports_are_declared_and_exported" {
  command = plan

  variables {
    named_ports = {
      http = 80
      grpc = 8080
    }
  }

  assert {
    condition     = length(google_compute_instance_group_manager.this.named_port) == 2
    error_message = "Both named ports should be declared on the group."
  }

  assert {
    condition = length([
      for named_port in google_compute_instance_group_manager.this.named_port :
      named_port if named_port.name == "http" && named_port.port == 80
    ]) == 1
    error_message = "The http named port should be declared as port 80."
  }

  assert {
    condition     = output.named_ports == { http = 80, grpc = 8080 }
    error_message = "The named_ports output must mirror the ports actually declared on the group."
  }
}

run "auto_healing_defaults_to_a_generous_initial_delay" {
  command = plan

  variables {
    auto_healing_policy = {
      health_check = "projects/example-project/global/healthChecks/test"
    }
  }

  assert {
    condition     = one(google_compute_instance_group_manager.this.auto_healing_policies).initial_delay_sec == 300
    error_message = "initial_delay_sec should default to 300s so instances are not healed while they are still booting."
  }

  assert {
    condition     = one(google_compute_instance_group_manager.this.auto_healing_policies).health_check == "projects/example-project/global/healthChecks/test"
    error_message = "The supplied health check should be attached to the auto-healing policy."
  }
}

run "proactive_rollout_is_allowed_when_a_health_check_exists" {
  command = plan

  variables {
    auto_healing_policy = {
      health_check      = "projects/example-project/global/healthChecks/test"
      initial_delay_sec = 420
    }
    update_policy = {
      type                           = "PROACTIVE"
      minimal_action                 = "REPLACE"
      most_disruptive_allowed_action = "REPLACE"
      max_surge_fixed                = 1
      max_unavailable_fixed          = 0
    }
  }

  assert {
    condition     = one(google_compute_instance_group_manager.this.update_policy).type == "PROACTIVE"
    error_message = "The update policy type should be passed through."
  }

  assert {
    condition     = one(google_compute_instance_group_manager.this.update_policy).minimal_action == "REPLACE"
    error_message = "minimal_action should be passed through."
  }

  assert {
    condition     = one(google_compute_instance_group_manager.this.auto_healing_policies).initial_delay_sec == 420
    error_message = "An explicit initial_delay_sec should override the default."
  }
}
