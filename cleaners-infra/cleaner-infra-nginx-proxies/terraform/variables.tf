variable "droplet_count" { type = number }


variable "domain_name" { 
    type = string 
    default = "d34.com.br"
}
variable "ssh_key_name" { 
    type = string 

}

variable "environment" {
  description = "The name of the environment (e.g., dev, staging, prod)."
  type        = string
  default     = "prod"
}

variable "region" {
  description = "The DigitalOcean region to deploy resources in."
  type        = string
  default     = "nyc3"
}

variable "droplet_image" {
  description = "The OS image slug for the Droplet."
  type        = string
  default     = "ubuntu-22-04-x64"
}

variable "droplet_size" {
  description = "The slug for the Droplet size."
  type        = string
  default     = "s-1vcpu-1gb"
}