##### Provider ####
provider "aws" {
  region = "eu-west-1"
}

##### Vars #####

variable "server_port" {
  description    = "Port that the server will use for HTTP requests"
  type           = number
  default        = 8080
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

##### Services #####

resource "aws_launch_configuration" "cluster_config" {
  image_id                        = "ami-07042e91d04b1c30d"
  instance_type                   = "t2.micro"
  security_groups                 = [aws_security_group.http_ingress.id]
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, world" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF

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

##### Output #####

output "alb_dns_name" {
  description    = "Domain name of load balancer"
  value          = aws_lb.lb.dns_name
}
