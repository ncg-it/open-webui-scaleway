variable "region" {
  description = "Scaleway-Region"
  type        = string
  default     = "nl-ams"
}

variable "zone" {
  description = "Scaleway-Zone"
  type        = string
  default     = "nl-ams-1"
}

variable "name" {
  description = "Präfix für alle Ressourcen"
  type        = string
  default     = "open-webui"
}

variable "instance_type" {
  description = "Instance-Typ (2 vCPU / 4 GB RAM reichen, da Modelle und Embeddings über die Generative APIs laufen)"
  type        = string
  default     = "PLAY2-MICRO"
}

variable "image" {
  description = "Betriebssystem-Image"
  type        = string
  default     = "ubuntu_noble"
}

variable "root_volume_size_gb" {
  description = "Größe des System-Volumes in GB"
  type        = number
  default     = 20
}

variable "data_volume_size_gb" {
  description = "Größe des Daten-Volumes (Chats, Uploads, Vektor-DB, Zertifikate) in GB"
  type        = number
  default     = 20
}

variable "ssh_public_key" {
  description = "Öffentlicher SSH-Key für den Benutzer 'deploy'"
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "Quell-Netze für SSH (Port 22). GitHub-Actions-Runner haben wechselnde IPs, daher Standard 0.0.0.0/0 – Login ist nur per Key möglich."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "domain" {
  description = "Vollständiger Hostname von Open WebUI"
  type        = string
  default     = "chat.ncg-it.com"
}

variable "dns_zone" {
  description = "Nur setzen, wenn die DNS-Zone bei Scaleway Domains & DNS liegt (z. B. 'ncg-it.com'). Leer = A-Record manuell beim DNS-Anbieter anlegen."
  type        = string
  default     = ""
}
