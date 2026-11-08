variable "region" {
  description = "Scaleway region"
  type        = string
  default     = "nl-ams"
}

variable "zone" {
  description = "Scaleway zone"
  type        = string
  default     = "nl-ams-1"
}

variable "name" {
  description = "Prefix for all resources"
  type        = string
  default     = "open-webui"
}

variable "instance_type" {
  description = "Instance type (2 vCPU / 4 GB RAM is enough, since models and embeddings run via the Generative APIs)"
  type        = string
  default     = "PLAY2-MICRO"
}

variable "image" {
  description = "Operating system image"
  type        = string
  default     = "ubuntu_noble"
}

variable "root_volume_size_gb" {
  description = "Size of the system volume in GB"
  type        = number
  default     = 20
}

variable "data_volume_size_gb" {
  description = "Size of the data volume (chats, uploads, vector DB, certificates) in GB"
  type        = number
  default     = 20
}

variable "ssh_public_key" {
  description = "Public SSH key for the user 'deploy'"
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "Source networks for SSH (port 22). GitHub Actions runners have changing IPs, hence the default 0.0.0.0/0 - login is key-only."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "domain" {
  description = "Fully qualified hostname of Open WebUI"
  type        = string
  default     = "chat.ncg-it.com"
}

variable "dns_zone" {
  description = "Only set if the DNS zone is hosted at Scaleway Domains & DNS (e.g. 'ncg-it.com'). Empty = create the A record manually at the DNS provider."
  type        = string
  default     = ""
}
