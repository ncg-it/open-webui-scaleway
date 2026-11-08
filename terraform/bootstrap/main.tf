# Einmalig ausführen: legt den Bucket für den Terraform-State an (lokaler State).
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.91"
    }
  }
}

provider "scaleway" {
  region = "nl-ams"
}

resource "scaleway_object_bucket" "tfstate" {
  name = "ncg-it-openwebui-tfstate"

  versioning {
    enabled = true
  }

  tags = {
    purpose = "terraform-state"
  }
}

resource "scaleway_object_bucket_acl" "tfstate" {
  bucket = scaleway_object_bucket.tfstate.id
  acl    = "private"
}
