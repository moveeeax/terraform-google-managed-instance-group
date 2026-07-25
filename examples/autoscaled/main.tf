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

resource "google_compute_instance_template" "example" {
  project      = var.project_id
  name_prefix  = "autoscaled-mig-"
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

resource "google_compute_health_check" "example" {
  project             = var.project_id
  name                = "autoscaled-mig-health"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 80
    request_path = "/healthz"
  }
}

module "mig" {
  source = "../.."

  project_id         = var.project_id
  name               = "autoscaled-mig"
  zone               = "${var.region}-a"
  base_instance_name = "autoscaled"
  instance_template  = google_compute_instance_template.example.self_link

  # The autoscaler below owns the instance count. Leaving target_size at its
  # default would make Terraform resize the group back on every apply and fight
  # the autoscaler for control of it.
  target_size = null

  named_ports = {
    http = 80
  }

  auto_healing_policy = {
    health_check      = google_compute_health_check.example.self_link
    initial_delay_sec = 300
  }
}

resource "google_compute_autoscaler" "example" {
  project = var.project_id
  name    = "autoscaled-mig"
  zone    = "${var.region}-a"
  target  = module.mig.id

  autoscaling_policy {
    min_replicas    = 2
    max_replicas    = 10
    cooldown_period = 300

    cpu_utilization {
      target = 0.7
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

output "autoscaler_id" {
  value = google_compute_autoscaler.example.id
}
