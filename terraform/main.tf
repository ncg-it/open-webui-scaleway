locals {
  tags = ["open-webui", "managed-by-terraform"]
}

resource "scaleway_instance_ip" "this" {
  tags = local.tags
}

resource "scaleway_instance_security_group" "this" {
  name                    = "${var.name}-sg"
  inbound_default_policy  = "drop"
  outbound_default_policy = "accept"
  stateful                = true

  inbound_rule {
    action   = "accept"
    port     = 80
    ip_range = "0.0.0.0/0"
  }

  inbound_rule {
    action   = "accept"
    port     = 443
    ip_range = "0.0.0.0/0"
  }

  # HTTP/3
  inbound_rule {
    action   = "accept"
    protocol = "UDP"
    port     = 443
    ip_range = "0.0.0.0/0"
  }

  dynamic "inbound_rule" {
    for_each = var.ssh_allowed_cidrs
    content {
      action   = "accept"
      port     = 22
      ip_range = inbound_rule.value
    }
  }
}

# Separates Daten-Volume: überlebt einen Neuaufbau der Instance und wird per Snapshot gesichert.
resource "scaleway_block_volume" "data" {
  name       = "${var.name}-data"
  size_in_gb = var.data_volume_size_gb
  iops       = 5000
  tags       = local.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "scaleway_instance_server" "this" {
  name              = var.name
  type              = var.instance_type
  image             = var.image
  ip_id             = scaleway_instance_ip.this.id
  security_group_id = scaleway_instance_security_group.this.id
  tags              = local.tags

  root_volume {
    size_in_gb  = var.root_volume_size_gb
    volume_type = "sbs_volume"
  }

  additional_volume_ids = [scaleway_block_volume.data.id]

  user_data = {
    cloud-init = templatefile("${path.module}/cloud-init.yaml.tftpl", {
      ssh_public_key = trimspace(var.ssh_public_key)
      data_volume_id = element(split("/", scaleway_block_volume.data.id), 1)
    })
  }

  lifecycle {
    # Änderungen am cloud-init sollen die laufende Instance nicht ungefragt neu bauen.
    ignore_changes = [user_data, image]
  }
}

resource "scaleway_domain_record" "chat" {
  count = var.dns_zone == "" ? 0 : 1

  dns_zone = var.dns_zone
  name     = trimsuffix(trimsuffix(var.domain, var.dns_zone), ".")
  type     = "A"
  data     = scaleway_instance_ip.this.address
  ttl      = 300
}
