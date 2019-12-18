

provider "aws" {
  version = "~> 2.0"
  region  = "us-east-1" 
}


# Use this as backend
# Use as
#. terraform init -backend-config=docker.tfbackend
terraform {  
    backend "s3" {
#       bucket  = "eiac-144153993531-us-east-1-bootstrap"
        encrypt = true
#        key     = "terraform.tfstate"    
        region  = "us-east-1"  
        dynamodb_table = "eiac-144153993531-us-east-1"
    }
}
