##### Provider ####
provider "aws" {
  region = "eu-west-1"
}

##### Backend ####
terraform {
  backend "s3" {
    bucket         = "another-terraform-up-and-running-state"
    key            = "stage/services/webserver-cluster/terraform.tfstate"
    region         = "eu-west-1"

    dynamodb_table = "terraform-up-and-running-locks"
    encrypt        = true
  }
}

##### Data ####

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = "another-terraform-up-and-running-state"
    key    = "stage/data-stores/mysql/terraform.tfstate"
    region = "eu-west-1"
  }
}

##### Services #####
resource "aws_launch_configuration" "cluster_config" {
  image_id                        = "ami-07042e91d04b1c30d"
  instance_type                   = "t2.micro"
  security_groups                 = [aws_security_group.http_ingress.id]
  user_data = templatefile("user-data.sh", { 
    server_port = "${var.server_port}", 
    db_port = "${data.terraform_remote_state.db.outputs.port}",
    db_address = "${data.terraform_remote_state.db.outputs.address}"
  })

  # Required for launch config with ASG
  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_autoscaling_group" "cluster" {
  launch_configuration           = aws_launch_configuration.cluster_config.name
  vpc_zone_identifier            = data.aws_subnet_ids.default.ids

  target_group_arns              = [aws_lb_target_group.asg.arn]
  health_check_type              = "ELB"

  min_size                       = 2
  max_size                       = 10
  tag {
    key                         = "Name"
    value                       = "cluster_asg"
    propagate_at_launch         = true
  }
}

resource "aws_lb" "lb" {
  name                 = "balancer"
  load_balancer_type   = "application"
  subnets              = data.aws_subnet_ids.default.ids
  security_groups      = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn         = aws_lb.lb.arn
  port                      = 80
  protocol                  = "HTTP"

  # by default return 404
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type     = "text/plain"
      message_body     = "404: page not found"
      status_code      = 404
    }
  }
}

resource "aws_lb_target_group" "asg" {
  name        = "terraform-asg-example"
  port        = var.server_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority = 100
  condition {
    path_pattern {
      values = ["*"]
    }
  }
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

##### Firewall #####
resource "aws_security_group" "http_ingress" {
  name = "http_proxy_server"

  ingress {
    from_port     = var.server_port
    to_port       = var.server_port
    protocol      = "tcp"
    cidr_blocks   = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb" {
  name = "alb_server"

  ingress {
    from_port      = 80
    to_port        = 80
    protocol       = "tcp"
    cidr_blocks    = ["0.0.0.0/0"]
  }

  egress {
    from_port      = 0
    to_port        = 0
    protocol       = -1
    cidr_blocks    = ["0.0.0.0/0"]
  }
}

