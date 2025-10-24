output "app_server_ip" {
  description = "IP público do Droplet da aplicação."
  value       = digitalocean_droplet.app_server.ipv4_address
}