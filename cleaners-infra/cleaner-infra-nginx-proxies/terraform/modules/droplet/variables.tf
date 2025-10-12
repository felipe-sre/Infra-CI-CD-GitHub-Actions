variable "droplet_count" {
  description = "Número de Droplets a serem criados."
  type        = number
  default     = 1
}
variable "name_prefix" {
  description = "Prefixo para os nomes dos Droplets."
  type        = string
}
variable "region" {
  description = "Região da DigitalOcean."
  type        = string
}
variable "droplet_size" {
  description = "O tamanho do Droplet (slug)."
  type        = string
}
variable "tag_name" {
  description = "A tag para associar aos Droplets."
  type        = string
}
variable "ssh_key_name" {
  description = "O nome da chave SSH cadastrada na DigitalOcean."
  type        = string
}
