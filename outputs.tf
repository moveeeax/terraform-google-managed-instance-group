output "id" {
  description = "Identifier of the managed instance group."
  value       = google_compute_instance_group_manager.this.id
}

output "self_link" {
  description = "URI of the managed instance group."
  value       = google_compute_instance_group_manager.this.self_link
}

output "instance_group" {
  description = "Self link of the instance group resource created by the manager."
  value       = google_compute_instance_group_manager.this.instance_group
}

output "named_ports" {
  description = <<-EOT
    Named ports actually declared on the group, keyed by port name. Wire a
    backend service's `port_name` from this map instead of repeating a string
    literal: a `port_name` the group does not declare produces no error, just a
    backend service whose health checks never pass.
  EOT
  value       = { for named_port in google_compute_instance_group_manager.this.named_port : named_port.name => named_port.port }
}
