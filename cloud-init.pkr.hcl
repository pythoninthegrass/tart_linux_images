source "tart-cli" "tart" {
  vm_base_name = "${var.vm_base_name}"
  vm_name = "${var.vm_name}"
  cpu_count = "${var.cpu_count}"
  memory_gb = "${var.memory_gb}"
  disk_size_gb = "${var.disk_size_gb}"
  ssh_username = "${var.ssh_username}"
  ssh_password = "${var.ssh_password}"
  run_extra_args = ["--disk", "cloud-init.iso"]
  display = "${var.display}"
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
    playbook_file = var.playbook
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
      "command -v apt-get >/dev/null && sudo apt-get clean || true",
      "sudo rm -rf /var/lib/apt/lists/*",
      "command -v dnf >/dev/null && sudo dnf clean all || true",
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
