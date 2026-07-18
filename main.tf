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
}
