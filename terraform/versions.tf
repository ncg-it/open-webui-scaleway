terraform {
  required_version = ">= 1.6.0"

  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.91"
    }
  }

  # State liegt in Scaleway Object Storage (Bucket wird mit terraform/bootstrap angelegt).
  # Zugangsdaten: AWS_ACCESS_KEY_ID=$SCW_ACCESS_KEY und AWS_SECRET_ACCESS_KEY=$SCW_SECRET_KEY
  backend "s3" {
    bucket = "ncg-it-openwebui-tfstate"
    key    = "open-webui/terraform.tfstate"
    region = "nl-ams"

    endpoints = {
      s3 = "https://s3.nl-ams.scw.cloud"
    }

    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}

provider "scaleway" {
  region = var.region
  zone   = var.zone
}
