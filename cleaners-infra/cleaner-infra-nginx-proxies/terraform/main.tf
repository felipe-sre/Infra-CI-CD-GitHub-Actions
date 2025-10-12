locals {
  name_prefix = terraform.workspace
  tag_name    = "env:${terraform.workspace}"
}

module "droplets" {
  source        = "./modules/droplet"
  droplet_count = var.droplet_count
  name_prefix   = "${local.name_prefix}-nginx-proxy"
  region        = var.region
  droplet_size  = var.droplet_size
  tag_name      = local.tag_name
  ssh_key_name  = var.ssh_key_name
}

module "firewall" {
  source      = "./modules/firewall"
  name_prefix = "${local.name_prefix}-nginx-proxy"
  tag_name    = local.tag_name
}

resource "digitalocean_record" "domain_a_record" {
  domain = trimsuffix(var.domain_name, ".")
  type   = "A"
  name   = var.domain_name
  value  = module.droplets.droplet_ips[0]
  ttl    = 60
}
