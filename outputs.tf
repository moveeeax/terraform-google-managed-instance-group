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
