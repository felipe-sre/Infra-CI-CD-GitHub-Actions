terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}
resource "digitalocean_droplet" "web_node" {
  count    = var.droplet_count
  image    = "ubuntu-22-04-x64"
  name     = "${var.name_prefix}-${count.index + 1}"
  region   = var.region
  size     = var.droplet_size
  tags     = [var.tag_name]
  ssh_keys = [data.digitalocean_ssh_key.main_ssh_key.id]
}

data "digitalocean_ssh_key" "main_ssh_key" {
  name = var.ssh_key_name
}
