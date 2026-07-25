locals {
  # An update needs headroom somewhere: either the group may temporarily run
  # extra instances (surge) or it may take existing ones out of service
  # (unavailable). With both pinned to zero the rolling update can never make
  # progress and simply hangs.
  update_surge_zero = var.update_policy == null ? false : (
    var.update_policy.max_surge_fixed == 0 || var.update_policy.max_surge_percent == 0
  )
  update_unavailable_zero = var.update_policy == null ? false : (
    var.update_policy.max_unavailable_fixed == 0 || var.update_policy.max_unavailable_percent == 0
  )
}

resource "google_compute_instance_group_manager" "this" {
  project            = var.project_id
  name               = var.name
  zone               = var.zone
  base_instance_name = var.base_instance_name
  target_size        = var.target_size
  description        = var.description

  version {
    instance_template = var.instance_template
  }

  dynamic "named_port" {
    for_each = var.named_ports
    content {
      name = named_port.key
      port = named_port.value
    }
  }

  dynamic "auto_healing_policies" {
    for_each = var.auto_healing_policy == null ? [] : [var.auto_healing_policy]
    content {
      health_check      = auto_healing_policies.value.health_check
      initial_delay_sec = auto_healing_policies.value.initial_delay_sec
    }
  }

  dynamic "update_policy" {
    for_each = var.update_policy == null ? [] : [var.update_policy]
    content {
      type                           = update_policy.value.type
      minimal_action                 = update_policy.value.minimal_action
      most_disruptive_allowed_action = update_policy.value.most_disruptive_allowed_action
      replacement_method             = update_policy.value.replacement_method
      max_surge_fixed                = update_policy.value.max_surge_fixed
      max_surge_percent              = update_policy.value.max_surge_percent
      max_unavailable_fixed          = update_policy.value.max_unavailable_fixed
      max_unavailable_percent        = update_policy.value.max_unavailable_percent
    }
  }

  lifecycle {
    # Declared as preconditions rather than variable validations because they
    # span two variables, and cross-variable validation would require
    # Terraform >= 1.9 from every consumer of this module.
    precondition {
      condition     = try(var.update_policy.type, null) != "PROACTIVE" || var.auto_healing_policy != null
      error_message = "update_policy.type = PROACTIVE makes the group roll a new instance template across every instance on its own. Set auto_healing_policy as well so there is a health signal watching the rollout; otherwise a broken image is applied to the whole group unchecked."
    }

    precondition {
      condition     = !(local.update_surge_zero && local.update_unavailable_zero)
      error_message = "update_policy sets both max_surge and max_unavailable to zero, which leaves the rolling update no room to replace anything and it will never complete. Allow at least one of them to be greater than zero."
    }
  }
}
