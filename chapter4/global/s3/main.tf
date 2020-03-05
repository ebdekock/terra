##### Provider ####
provider "aws" {
  region = "eu-west-1"
}

##### Backend ####
terraform {
  backend "s3" {
    bucket         = "another-terraform-up-and-running-state"
    key            = "global/s3/terraform.tfstate"
    region         = "eu-west-1"

    dynamodb_table = "terraform-up-and-running-locks"
    encrypt        = true
  }
}

##### Services #####
resource "aws_s3_bucket" "terraform_state" {
  bucket = "another-terraform-up-and-running-state"
  
  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }
  
  # We want revision history of state
  versioning {
    enabled = true
  }
  
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name                             = "terraform-up-and-running-locks"
  billing_mode                     = "PAY_PER_REQUEST"
  hash_key                         = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
