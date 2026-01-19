# Konfiguracja Application Load Balancer (ALB)

# Tworzenie ALB
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-ALB"
  }
}

# Tworzenie Target Group dla backendu
resource "aws_lb_target_group" "backend" {
  name     = "${var.project_name}-backend-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/api/health/" # Endpoint sprawdzający stan aplikacji
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-backend-tg"
  }
}

# Tworzenie Listenera na porcie 80 (HTTP)
# W środowisku produkcyjnym powinien być listener na 443 (HTTPS) z certyfikatem ACM
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# Powiązanie instancji EC2 backendu z Target Group
# Rejestruje instancję EC2 jako cel dla ruchu przychodzącego.
resource "aws_lb_target_group_attachment" "backend_attach" {
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = aws_instance.backend.id
  port             = 8000
}
