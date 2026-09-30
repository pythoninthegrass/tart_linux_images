variable "vm_base_name" {
  type = string
  default = "ghcr.io/cirruslabs/ubuntu:latest"
}

variable "vm_name" {
  type = string
  default = "ubuntu"
}

variable "cpu_count" {
  type = number
  default = 2
}

variable "memory_gb" {
  type = number
  default = 3
}

variable "disk_size_gb" {
  type = number
  default = 32
}

variable "ssh_username" {
  type = string
}

variable "ssh_password" {
  type = string
}

variable "display" {
  type = string
}

variable "playbook" {
  type = string
  default = "customizations/mate-desktop.yml"
}
