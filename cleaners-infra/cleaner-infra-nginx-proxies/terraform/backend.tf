terraform {
  backend "s3" {
    endpoints                    = {
      s3 = "https://nyc3.digitaloceanspaces.com"
    }
    region                      = "us-east-1"
    bucket                      = "infrangninxreverseproxyd34"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    key                         = "infra-nginx-proxies/default/terraform.tfstate"
    skip_requesting_account_id  = true
  }
}
