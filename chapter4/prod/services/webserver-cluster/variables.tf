##### ASG specs #####

variable "cluster_name" {
  description = "The name to use for all the cluster resources"
  type        = string
  default     = "webservers-prod"
}

##### Remote State  #####

variable "db_remote_state_bucket" {
  description = "The name of the S3 bucket to use for the databases remote state"
  type        = string
  default     = "another-terraform-up-and-running-state"
}

variable "db_remote_state_key" {
  description = "The path for the databses remote state in S3"
  type        = string
  default     = "prod/data-stores/mysql/terraform.tfstate"
}
