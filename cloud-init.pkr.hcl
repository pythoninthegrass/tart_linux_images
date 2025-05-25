packer {
  required_plugins {
    tart = {
      source  = "github.com/cirruslabs/tart"
      version = "~> 1.7.0"
    }
    ansible = {
      version = "~> 1.1.3"
      source = "github.com/hashicorp/ansible"
    }
  }
}

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

source "tart-cli" "tart" {
  vm_base_name = "${var.vm_base_name}"
  vm_name = "${var.vm_name}"
  cpu_count = "${var.cpu_count}"
  memory_gb = "${var.memory_gb}"
  disk_size_gb = "${var.disk_size_gb}"
  ssh_username = "${var.ssh_username}"
  ssh_password = "${var.ssh_password}"
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

  provisioner "ansible" {
    playbook_file = "customizations/mate-desktop.yml"
    user          = var.ssh_username
    use_proxy     = false
    ansible_env_vars = [
      "ANSIBLE_HOST_KEY_CHECKING=False",
      "ANSIBLE_NOCOWS=1"
    ]
    ansible_ssh_extra_args = [
      "-o StrictHostKeyChecking=no",
      "-o UserKnownHostsFile=/dev/null",
      "-o PubkeyAuthentication=no",
      "-o PasswordAuthentication=yes"
    ]
    extra_arguments = [
      "--extra-vars",
      "ansible_ssh_pass=${var.ssh_password}"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "sudo cloud-init clean --logs",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/dbus/machine-id"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo touch /etc/cloud/cloud-init.disabled"
    ]
  }
}
