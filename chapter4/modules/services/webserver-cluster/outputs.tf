output "alb_dns_name" {
  description    = "Domain name of load balancer"
  value          = aws_lb.lb.dns_name
}

output "asg_name" {
  description   = "Name of the auto scaling cluster of web servers"
  value         = aws_autoscaling_group.cluster.name
}

output "alb_security_group_id" {
  description   = "The ID of the security group attached to the load balancer"
  value         = aws_security_group.alb.id
}
