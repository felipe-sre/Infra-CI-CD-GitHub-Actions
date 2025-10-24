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

# Se você deseja que o domínio raiz aponte para o Droplet, descomente 'ip_address'.
data "digitalocean_domain" "main" {
  name       = var.domain_name
  # ip_address = digitalocean_droplet.app_server.ipv4_address 
}

resource "digitalocean_record" "domain_a_record" {
  domain = trimsuffix(var.domain_name, ".")
  type   = "A"
  name   = var.domain_name
  value  = module.droplets.droplet_ips[0]
  ttl    = 60
}

resource "digitalocean_record" "subdomain_a_records" {
  for_each = toset(var.subdomains)
  domain = data.digitalocean_domain.main.id
  type   = "A"
  name   = each.key
  value  = digitalocean_droplet.app_server.ipv4_address
  ttl    = 60 
}

data "digitalocean_ssh_key" "default" {
  name = var.ssh_key_name
}

resource "digitalocean_droplet" "app_server" {
  name   = var.project_name_prefix  
  region = var.region
  image  = "ubuntu-22-04-x64"                                  
  size   = "s-1vcpu-1gb"                               
  ssh_keys = [data.digitalocean_ssh_key.default.id]
}