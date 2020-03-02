output "alb_dns_name" {
  description    = "Domain name of load balancer"
  value          = aws_lb.lb.dns_name
}
