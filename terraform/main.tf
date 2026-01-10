locals {
  cp_instances = [for i in range(var.cluster_size.controlplanes) : format("%s-cp-%s", var.cluster_name, i + 1)]
}

resource "libvirt_volume" "cp" {
  for_each = toset(local.cp_instances)

  name = each.value
  size = 6442450944
}

resource "libvirt_domain" "cp" {
  for_each = toset(local.cp_instances)

  lifecycle {
    ignore_changes = [
      nvram,
    ]
  }
  name     = each.value
  console {
    type        = "pty"
    target_port = "0"
  }
  cpu {
    mode = "host-passthrough"
  }
  disk {
    file = var.iso_path
  }
  disk {
    volume_id = libvirt_volume.cp[each.key].id
  }
  boot_device {
    dev = ["cdrom"]
  }
  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }
  vcpu   = "2"
  memory = "4096"
}

resource "talos_machine_secrets" "this" {}

data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = format("https://%s:6443", values(libvirt_domain.cp)[0].network_interface[0].addresses[0])
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = "1.35.0"
  config_patches     = [
    file("${path.module}/files/customization.yaml")
  ]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for cp in libvirt_domain.cp : cp.network_interface[0].addresses[0]]
}

resource "talos_machine_configuration_apply" "controlplane" {
  for_each = toset(local.cp_instances)

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = libvirt_domain.cp[each.key].network_interface[0].addresses[0]
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = values(libvirt_domain.cp)[0].network_interface[0].addresses[0]
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = values(libvirt_domain.cp)[0].network_interface[0].addresses[0]
}
