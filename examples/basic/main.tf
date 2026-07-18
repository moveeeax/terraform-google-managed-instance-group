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

module "mig" {
  source = "../.."

  project_id         = var.project_id
  name               = "example-mig"
  zone               = "${var.region}-a"
  base_instance_name = "example"
  instance_template  = google_compute_instance_template.example.self_link
  target_size        = 2

  named_ports = {
    http = 80
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
