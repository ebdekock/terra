##### Provider #####
provider "aws" {
  region = "eu-west-1"
}

##### Backend ####
terraform {
  backend "s3" {
    bucket         = "another-terraform-up-and-running-state"
    key            = "prod/data-stores/mysql/terraform.tfstate"
    region         = "eu-west-1"

    dynamodb_table = "terraform-up-and-running-locks"
    encrypt        = true
  }
}


##### Services #####
resource "aws_db_instance" "db" {
  engine                 = "mysql"
  allocated_storage      = 10
  instance_class         = "db.t2.micro"
  name                   = "db"
  username               = "admin"
  password               = jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)["db"]
  skip_final_snapshot    = true
}

data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "mysql-master-password-prod"
}
