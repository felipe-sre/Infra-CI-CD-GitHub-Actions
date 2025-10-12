output "droplet_ips" {
  description = "Lista de IPs públicos dos Droplets."
  value       = digitalocean_droplet.web_node[*].ipv4_address
}
