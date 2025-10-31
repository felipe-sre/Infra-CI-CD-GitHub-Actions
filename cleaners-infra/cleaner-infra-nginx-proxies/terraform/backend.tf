terraform {
   backend "s3" {
     endpoint                    = {
       s3 = "https://nyc3.digitaloceanspaces.com"
     }
     region                      = "us-east-1"
     bucket                      = "cleaner-backend"
     key                         = "cleaner-backend/default/terraform.tfstate"
     skip_credentials_validation = true
     skip_metadata_api_check     = true
     skip_region_validation      = true
     force_path_style            = true
 }
}

