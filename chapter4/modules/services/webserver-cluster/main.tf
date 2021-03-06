##### Locals #####
locals {
  http_port      = 80
  all_ports      = 0
  tcp_protocol   = "tcp"
  all_protocols  = "-1"
  all_ips        = ["0.0.0.0/0"]
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
    bucket = var.db_remote_state_bucket
    key    = var.db_remote_state_key
    region = "eu-west-1"
  }
}

##### Services #####
resource "aws_launch_configuration" "cluster_config" {
  image_id                        = "ami-07042e91d04b1c30d"
  instance_type                   = var.instance_type
  security_groups                 = [aws_security_group.instance.id]
  user_data = templatefile("${path.module}/user-data.sh", { 
    server_port = var.server_port, 
    db_port     = data.terraform_remote_state.db.outputs.port,
    db_address  = data.terraform_remote_state.db.outputs.address
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

  min_size                       = var.min_size
  max_size                       = var.max_size
  tag {
    key                         = "Name"
    value                       = var.cluster_name
    propagate_at_launch         = true
  }
}

resource "aws_lb" "lb" {
  name                 = var.cluster_name
  load_balancer_type   = "application"
  subnets              = data.aws_subnet_ids.default.ids
  security_groups      = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn         = aws_lb.lb.arn
  port                      = local.http_port
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
  name        = var.cluster_name
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
resource "aws_security_group" "instance" {
  name = "${var.cluster_name}-instance"
}

resource "aws_security_group_rule" "proxy_traffic" {
  security_group_id = aws_security_group.instance.id
  type              = "ingress"
  from_port         = var.server_port
  to_port           = var.server_port
  protocol          = local.tcp_protocol
  cidr_blocks       = local.all_ips
}

resource "aws_security_group" "alb" {
  name = "${var.cluster_name}-alb"
}

resource "aws_security_group_rule" "alb_ingress" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  from_port         = local.http_port
  to_port           = local.http_port
  protocol          = local.tcp_protocol
  cidr_blocks       = local.all_ips
}

resource "aws_security_group_rule" "alb_egress" {
  security_group_id = aws_security_group.alb.id
  type              = "egress"
  from_port         = local.all_ports
  to_port           = local.all_ports
  protocol          = local.all_protocols
  cidr_blocks       = local.all_ips
}

