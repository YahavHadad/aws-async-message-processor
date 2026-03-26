resource "aws_elb" "this" {
  name            = "${var.name}-clb"
  subnets         = var.public_subnet_ids
  security_groups = [var.lb_security_group_id]

  listener {
    lb_port           = 80
    lb_protocol       = "HTTP"
    instance_port     = var.container_port
    instance_protocol = "HTTP"
  }

  health_check {
    target              = "HTTP:${var.container_port}/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  cross_zone_load_balancing   = true
  connection_draining         = true
  connection_draining_timeout = 30

  tags = { Name = "${var.name}-clb" }
}
