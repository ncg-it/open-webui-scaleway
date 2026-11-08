output "public_ip" {
  description = "Öffentliche IP – als A-Record für die Domain eintragen"
  value       = scaleway_instance_ip.this.address
}

output "ssh" {
  description = "SSH-Zugang"
  value       = "ssh deploy@${scaleway_instance_ip.this.address}"
}

output "data_volume_id" {
  description = "ID des Daten-Volumes (für Snapshot-Backups, als GitHub-Variable DATA_VOLUME_ID hinterlegen)"
  value       = element(split("/", scaleway_block_volume.data.id), 1)
}

output "url" {
  value = "https://${var.domain}"
}
