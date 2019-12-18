
provider "aws" {
  version = "~> 2.0"
  region  = "us-east-1" 
}

# create-dynamodb-lock-table.tf
resource "aws_dynamodb_table" "dynamodb-terraform-state-lock" {
  name           = "eiac-144153993531-us-east-1"
  hash_key       = "LockID"
  read_capacity  = 5
  write_capacity = 5
  attribute {
        name = "LockID"
        type = "S"
  }
  tags = {
        Name = "DynamoDB Terraform State Lock Table"
  }
}


