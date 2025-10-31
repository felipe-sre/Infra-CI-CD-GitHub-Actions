terraform {
   backend "s3" {
     endpoints                    = {
       s3 = "https://nyc3.digitaloceanspaces.com"
     }
     region                      = "us-east-1"
     bucket                      = "cleaner-backend"
     key                         = "cleaner-backend/default/terraform.tfstate"
     skip_credentials_validation = true
     skip_metadata_api_check     = true
     skip_requesting_account_id  = true
     skip_region_validation      = true
     use_path_style           = true
 }
}

