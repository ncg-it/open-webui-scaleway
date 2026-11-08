output "public_ip" {
  description = "Public IP - add it as the A record for the domain"
  value       = scaleway_instance_ip.this.address
}

output "ssh" {
  description = "SSH access"
  value       = "ssh deploy@${scaleway_instance_ip.this.address}"
}

output "data_volume_id" {
  description = "ID of the data volume (for snapshot backups, store as GitHub variable DATA_VOLUME_ID)"
  value       = element(split("/", scaleway_block_volume.data.id), 1)
}

output "url" {
  value = "https://${var.domain}"
}

output "server_id" {
  description = "ID of the instance (for the cost guard, store as GitHub variable SERVER_ID)"
  value       = element(split("/", scaleway_instance_server.this.id), 1)
}
