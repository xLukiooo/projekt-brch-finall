# Definicje Grup Bezpieczeństwa (Security Groups)

# Grupa bezpieczeństwa dla Application Load Balancer (ALB)
# Pozwala na ruch przychodzący HTTP i HTTPS z dowolnego miejsca w internecie.
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP/HTTPS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# Grupa bezpieczeństwa dla hosta bastionowego
# Pozwala na ruch SSH tylko z określonego adresu IP.
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "Allow SSH from my IP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from My IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}

# Grupa bezpieczeństwa dla instancji EC2 backendu (Django)
# Pozwala na ruch na porcie 8000 tylko z ALB oraz SSH tylko z bastionu.
resource "aws_security_group" "backend_ec2" {
  name        = "${var.project_name}-backend-ec2-sg"
  description = "Allow traffic from ALB and SSH from Bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Django port from ALB"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-backend-ec2-sg"
  }
}

# Grupa bezpieczeństwa dla bazy danych RDS
# Pozwala na ruch na porcie 3306 (MySQL) tylko z instancji EC2 backendu.
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow MySQL traffic from backend EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from backend EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}
