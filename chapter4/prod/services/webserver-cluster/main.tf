##### Provider ####
provider "aws" {
  region = "eu-west-1"
}

##### Backend ####
terraform {
  backend "s3" {
    bucket         = "another-terraform-up-and-running-state"
    key            = "prod/services/webserver-cluster/terraform.tfstate"
    region         = "eu-west-1"

    dynamodb_table = "terraform-up-and-running-locks"
    encrypt        = true
  }
}

##### Modules ####
module "webserver_cluster" {
  source = "../../../modules/services/webserver-cluster"

  cluster_name                = var.cluster_name
  db_remote_state_bucket      = var.db_remote_state_bucket
  db_remote_state_key         = var.db_remote_state_key

  instance_type               = "t2.micro"
  min_size                    = 2
  max_size                    = 10
}

##### Prod Specifics ####
resource "aws_autoscaling_schedule" "scale_out_business_hours" {
  scheduled_action_name       = "scale-out-during-business-hours"
  min_size                    = 2
  max_size                    = 10
  desired_capacity            = 10
  recurrence                  = " 0 9 * * *"
  autoscaling_group_name      = module.webserver_cluster.asg_name
}

resource "aws_autoscaling_schedule" "scale_out_business_hours" {
  scheduled_action_name       = "scale-out-during-business-hours"
  min_size                    = 2
  max_size                    = 10
  desired_capacity            = 2
  recurrence                  = " 0 17 * * *"
  autoscaling_group_name      = module.webserver_cluster.asg_name
}
