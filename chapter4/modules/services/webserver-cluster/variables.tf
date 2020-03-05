variable "server_port" {
  description    = "Port that the server will use for HTTP requests"
  type           = number
  default        = 8080
}

##### ASG specs #####

variable "cluster_name" {
  description = "The name to use for all the cluster resources"
  type        = string
}

variable "instance_type" {
  description = "AWS EC2 instance size"
  type        = string
  default     = "t2.micro"
}

variable "min_size" {
  description = "AWS Autoscaling groups minimum number of servers"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "AWS Autoscaling groups maximum number of servers"
  type        = number
  default     = 10
}

##### Remote State  #####

variable "db_remote_state_bucket" {
  description = "The name of the S3 bucket to use for the databases remote state"
  type        = string
}

variable "db_remote_state_key" {
  description = "The path for the databses remote state in S3"
  type        = string
}
