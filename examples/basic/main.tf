terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  # Single source of truth for the port name. The group declares it and the
  # backend service selects it; a literal repeated in both places is the classic
  # way to end up with a backend service whose health checks never pass.
  backend_port_name = "http"
  backend_port      = 80
}

resource "google_compute_instance_template" "example" {
  project      = var.project_id
  name_prefix  = "example-mig-"
  machine_type = "e2-small"

  disk {
    source_image = "debian-cloud/debian-12"
    boot         = true
  }

  network_interface {
    network = "default"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# The health signal behind both auto-healing and the backend service. Without it
# the group can only notice a VM that has stopped, never an application that has
# hung while the VM stays up.
resource "google_compute_health_check" "example" {
  project             = var.project_id
  name                = "example-mig-health"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = local.backend_port
    request_path = "/healthz"
  }
}

module "mig" {
  source = "../.."

  project_id         = var.project_id
  name               = "example-mig"
  zone               = "${var.region}-a"
  base_instance_name = "example"
  instance_template  = google_compute_instance_template.example.self_link
  target_size        = 2

  named_ports = {
    (local.backend_port_name) = local.backend_port
  }

  auto_healing_policy = {
    health_check = google_compute_health_check.example.self_link

    # Must comfortably exceed boot plus application warm-up. Too low and the
    # group recreates instances that were still starting, forever.
    initial_delay_sec = 300
  }

  # A proactive rollout replaces instances by itself when the template changes,
  # so the module only accepts it alongside the auto_healing_policy above. One
  # instance of surge headroom keeps serving capacity flat during the roll.
  update_policy = {
    type                           = "PROACTIVE"
    minimal_action                 = "REPLACE"
    most_disruptive_allowed_action = "REPLACE"
    max_surge_fixed                = 1
    max_unavailable_fixed          = 0
  }
}

resource "google_compute_backend_service" "example" {
  project       = var.project_id
  name          = "example-mig-backend"
  protocol      = "HTTP"
  port_name     = local.backend_port_name
  health_checks = [google_compute_health_check.example.id]

  backend {
    group = module.mig.instance_group
  }

  lifecycle {
    precondition {
      condition     = contains(keys(module.mig.named_ports), local.backend_port_name)
      error_message = "The managed instance group does not declare the port name this backend service selects, so no backend would ever be considered healthy."
    }
  }
}

variable "project_id" {
  description = "Project ID to deploy the example managed instance group into."
  type        = string
}

variable "region" {
  description = "Region for the google provider; zone is derived as region-a."
  type        = string
  default     = "us-central1"
}

output "mig_id" {
  value = module.mig.id
}

output "mig_named_ports" {
  value = module.mig.named_ports
}
