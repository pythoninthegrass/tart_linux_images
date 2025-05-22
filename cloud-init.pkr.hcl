packer {
  required_plugins {
    tart = {
      source  = "github.com/cirruslabs/tart"
      version = ">= 1.7.0"
    }
  }
}

variable "vm_base_name" {
  type = string
  default = "ghcr.io/cirruslabs/debian:bookworm"
}

variable "vm_name" {
  type = string
  default = "debian"
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

source "tart-cli" "tart" {
  vm_base_name = "${var.vm_base_name}"
  vm_name = "${var.vm_name}"
  cpu_count = "${var.cpu_count}"
  memory_gb = "${var.memory_gb}"
  disk_size_gb = "${var.disk_size_gb}"
  ssh_username = "admin"
  ssh_password = "admin"
  run_extra_args = ["--disk", "cloud-init.iso"]
  headless = false
  disable_vnc = true
}

build {
  sources = ["source.tart-cli.tart"]

  provisioner "file" {
    source = "99_cirruslabs.cfg"
    destination = "/tmp/99_cirruslabs.cfg"
  }

  provisioner "shell" {
    inline = [
      "cat /tmp/99_cirruslabs.cfg | sudo tee /etc/cloud/cloud.cfg.d/99_cirruslabs.cfg"
    ]
  }
}
