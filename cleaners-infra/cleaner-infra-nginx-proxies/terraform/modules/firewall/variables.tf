variable "name_prefix" {
  description = "Prefixo para o nome do firewall (ex: 'staging-web')"
  type        = string
}

variable "tag_name" {
  description = "A tag dos Droplets que este firewall protegerá."
  type        = string
}
