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
  description = "Target number of running instances in the group."
  type        = number
  default     = 2

  validation {
    condition     = var.target_size >= 0
    error_message = "target_size must be zero or greater."
  }
}

variable "named_ports" {
  description = "Named ports exposed by the group, keyed by port name."
  type        = map(number)
  default     = {}
}

variable "description" {
  description = "Optional description for the managed instance group."
  type        = string
  default     = null
}
