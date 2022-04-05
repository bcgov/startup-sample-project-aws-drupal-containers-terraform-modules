# alb.tf

# Use the default ALB that is pre-provisioned as part of the account creation
# This ALB has all traffic on *.LICENSE-PLATE-ENV.nimbus.cloud.gob.bc.ca routed to it
# data "aws_alb" "main" {
#   name = var.alb_name
# }

# # Redirect all traffic from the ALB to the target group
# data "aws_alb_listener" "front_end" {
#   load_balancer_arn = data.aws_alb.main.id
#   port              = 443
# }

resource "aws_lb" "main" {
  name               = "sample-drupal-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [data.aws_security_group.web.id]
  subnets            = module.network.aws_subnet_ids.web.ids #[for subnet in aws_subnet.public : subnet.id]

  enable_deletion_protection = false

  tags = local.common_tags
}


resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.acm_cert

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_drupal.arn
  }
}



resource "aws_lb_listener" "front_endHttp" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_drupal.arn
  }
}


resource "aws_lb_target_group" "app_drupal" {
  name                 = "sample-drupal-target-group"
  port                 = var.app_port
  protocol             = "HTTP"
  vpc_id               = module.network.aws_vpc.id
  target_type          = "ip"
  deregistration_delay = 30

  health_check {
    healthy_threshold   = "2"
    interval            = "5"
    protocol            = "HTTP"
    matcher             = "200,302,404"
    timeout             = "3"
    path                = var.health_check_path
    unhealthy_threshold = "2"
  }

  stickiness {
    type                = "lb_cookie"
  }

  tags = local.common_tags
}

resource "aws_lb_listener_rule" "host_based_weighted_routing" {
  listener_arn = aws_lb_listener.front_end.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_drupal.arn
  }

  condition {
    host_header {
      values = [for sn in var.service_names : "${sn}.*"]
    }
  }
}


resource "aws_lb_listener_rule" "host_based_weighted_routing_http" {
  listener_arn = aws_lb_listener.front_endHttp.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_drupal.arn
  }

  condition {
    host_header {
      values = [for sn in var.service_names : "${sn}.*"]
    }
  }
}
