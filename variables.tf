variable "project_id" {
  description = "ID of the project in which to create the managed instance group."
  type        = string
}

variable "name" {
  description = "Name of the managed instance group."
  type        = string
}

variable "zone" {
  description = "Zone in which to create the zonal managed instance group."
  type        = string
}

variable "base_instance_name" {
  description = "Base name used to generate names for instances in the group."
  type        = string
}

variable "instance_template" {
  description = "Self link of the instance template used to create instances."
  type        = string
}

variable "target_size" {
  description = <<-EOT
    Target number of running instances in the group. Set this to `null` when an
    autoscaler (for example `google_compute_autoscaler`) owns the size of this
    group: if both Terraform and an autoscaler manage the count they fight, and
    every plan shows a spurious resize back to this value.
  EOT
  type        = number
  default     = 2

  validation {
    condition     = var.target_size == null ? true : var.target_size >= 0
    error_message = "target_size must be zero or greater, or null to hand ownership of the size to an autoscaler."
  }
}

variable "named_ports" {
  description = <<-EOT
    Named ports exposed by the group, keyed by port name. A backend service that
    references a `port_name` the group does not declare will never see a healthy
    backend, so keep this map and the backend service `port_name` wired to the
    same source of truth -- the `named_ports` output exists for exactly that.
  EOT
  type        = map(number)
  default     = {}

  validation {
    condition     = alltrue([for port in values(var.named_ports) : port >= 1 && port <= 65535])
    error_message = "named_ports values must be TCP port numbers between 1 and 65535."
  }

  validation {
    condition     = alltrue([for port_name in keys(var.named_ports) : can(regex("^[a-z]([-a-z0-9]*[a-z0-9])?$", port_name))])
    error_message = "named_ports keys must be valid Compute Engine port names: lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "description" {
  description = "Optional description for the managed instance group."
  type        = string
  default     = null
}

variable "auto_healing_policy" {
  description = <<-EOT
    Auto-healing policy for the group. Leave `null` to disable auto-healing, in
    which case the group only recreates instances that Compute Engine itself
    considers gone -- an application that has hung on a running VM is never
    replaced.

    `health_check` is the self link of a `google_compute_health_check` and is
    mandatory whenever auto-healing is enabled: healing without a health signal
    is not possible.

    `initial_delay_sec` is how long a freshly created or recreated instance is
    exempt from healing. It must cover the slowest boot plus application warm-up
    in the group. Set it too low and the group kills instances that are still
    starting, then kills their replacements, and the group never converges.
  EOT
  type = object({
    health_check      = string
    initial_delay_sec = optional(number, 300)
  })
  default = null

  validation {
    condition     = var.auto_healing_policy == null ? true : trimspace(var.auto_healing_policy.health_check) != ""
    error_message = "auto_healing_policy.health_check must be the non-empty self link of a health check."
  }

  validation {
    condition = var.auto_healing_policy == null ? true : (
      var.auto_healing_policy.initial_delay_sec >= 0 && var.auto_healing_policy.initial_delay_sec <= 3600
    )
    error_message = "auto_healing_policy.initial_delay_sec must be between 0 and 3600 seconds."
  }
}

variable "update_policy" {
  description = <<-EOT
    Rolling update policy for the group. Leave `null` to keep the Compute Engine
    default, under which changing `instance_template` only affects instances
    created after the change.

    `type` is `PROACTIVE` (the group rolls the new template across existing
    instances by itself) or `OPPORTUNISTIC` (existing instances are only updated
    when something else recreates them). `PROACTIVE` requires
    `auto_healing_policy` to be set as well: an automatic rollout with no health
    signal will happily replace every instance in the group with a broken image
    and nothing will notice.

    `minimal_action` is the least disruptive action the updater may take
    (`NONE`, `REFRESH`, `RESTART`, `REPLACE`) and
    `most_disruptive_allowed_action` is the ceiling. If the ceiling is below the
    floor the updater silently declines to update anything, so the two are
    checked for coherence here.
  EOT
  type = object({
    type                           = string
    minimal_action                 = string
    most_disruptive_allowed_action = optional(string)
    replacement_method             = optional(string)
    max_surge_fixed                = optional(number)
    max_surge_percent              = optional(number)
    max_unavailable_fixed          = optional(number)
    max_unavailable_percent        = optional(number)
  })
  default = null

  validation {
    condition     = var.update_policy == null ? true : contains(["PROACTIVE", "OPPORTUNISTIC"], var.update_policy.type)
    error_message = "update_policy.type must be PROACTIVE or OPPORTUNISTIC."
  }

  validation {
    condition     = var.update_policy == null ? true : contains(["NONE", "REFRESH", "RESTART", "REPLACE"], var.update_policy.minimal_action)
    error_message = "update_policy.minimal_action must be one of NONE, REFRESH, RESTART, REPLACE."
  }

  validation {
    condition = var.update_policy == null ? true : (
      var.update_policy.most_disruptive_allowed_action == null ? true :
      contains(["NONE", "REFRESH", "RESTART", "REPLACE"], var.update_policy.most_disruptive_allowed_action)
    )
    error_message = "update_policy.most_disruptive_allowed_action must be one of NONE, REFRESH, RESTART, REPLACE."
  }

  validation {
    condition = var.update_policy == null ? true : (
      var.update_policy.most_disruptive_allowed_action == null ? true : try(
        index(["NONE", "REFRESH", "RESTART", "REPLACE"], var.update_policy.most_disruptive_allowed_action) >=
        index(["NONE", "REFRESH", "RESTART", "REPLACE"], var.update_policy.minimal_action),
        true
      )
    )
    error_message = "update_policy.most_disruptive_allowed_action must be at least as disruptive as minimal_action, otherwise the updater refuses to perform the update at all."
  }

  validation {
    condition = var.update_policy == null ? true : (
      var.update_policy.replacement_method == null ? true :
      contains(["RECREATE", "SUBSTITUTE"], var.update_policy.replacement_method)
    )
    error_message = "update_policy.replacement_method must be RECREATE or SUBSTITUTE."
  }

  validation {
    condition = var.update_policy == null ? true : (
      var.update_policy.replacement_method != "RECREATE" ? true : (
        coalesce(var.update_policy.max_unavailable_fixed, 0) > 0 ||
        coalesce(var.update_policy.max_unavailable_percent, 0) > 0
      )
    )
    error_message = "update_policy.replacement_method = RECREATE preserves instance names, so it requires max_unavailable_fixed or max_unavailable_percent to be greater than zero."
  }

  validation {
    condition = var.update_policy == null ? true : !(
      var.update_policy.max_surge_fixed != null && var.update_policy.max_surge_percent != null
    )
    error_message = "update_policy.max_surge_fixed and max_surge_percent are mutually exclusive; set at most one."
  }

  validation {
    condition = var.update_policy == null ? true : !(
      var.update_policy.max_unavailable_fixed != null && var.update_policy.max_unavailable_percent != null
    )
    error_message = "update_policy.max_unavailable_fixed and max_unavailable_percent are mutually exclusive; set at most one."
  }

  validation {
    condition = var.update_policy == null ? true : alltrue([
      for pct in [var.update_policy.max_surge_percent, var.update_policy.max_unavailable_percent] :
      pct == null ? true : (pct >= 0 && pct <= 100)
    ])
    error_message = "update_policy.max_surge_percent and max_unavailable_percent must be between 0 and 100."
  }

  validation {
    condition = var.update_policy == null ? true : alltrue([
      for fixed in [var.update_policy.max_surge_fixed, var.update_policy.max_unavailable_fixed] :
      fixed == null ? true : fixed >= 0
    ])
    error_message = "update_policy.max_surge_fixed and max_unavailable_fixed must be zero or greater."
  }
}
