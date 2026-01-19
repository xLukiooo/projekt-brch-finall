# Konfiguracja instancji EC2 (Bastion i Backend)

# Klucz SSH "test" został wygenerowany w konsoli AWS.

# --- Host Bastionowy ---
resource "aws_instance" "bastion" {
  ami                    = "ami-052064a798f08f0d3"
  instance_type          = "t2.micro" # Free Tier
  subnet_id              = aws_subnet.public[0].id
  key_name               = "test"
  vpc_security_group_ids = [aws_security_group.bastion.id]

  root_block_device {
    encrypted  = true
    kms_key_id = aws_kms_key.main.arn
  }

  tags = {
    Name = "${var.project_name}-Bastion"
  }
}

# --- Instancja Backendu (Django) ---
resource "aws_instance" "backend" {
  ami                    = "ami-052064a798f08f0d3"
  instance_type          = "t2.micro" # Free Tier
  subnet_id              = aws_subnet.private[0].id
  key_name               = "test"
  vpc_security_group_ids = [aws_security_group.backend_ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  root_block_device {
    encrypted  = true
    kms_key_id = aws_kms_key.main.arn
    tags = {
      Name   = "${var.project_name}-backend-root-volume"
      Backup = "true" # Tag dla polityki DLM
    }
  }

  # Skrypt User Data instaluje tylko niezbędne pakiety do uruchomienia aplikacji Python i połączenia z bazą danych.
  # Pełna konfiguracja aplikacji (pobranie kodu, instalacja zależności, uruchomienie usługi) jest realizowana
  # w sposób zautomatyzowany przez pipeline CI/CD (GitHub Actions) i AWS Systems Manager (SSM).
  user_data = <<-EOF
#!/bin/bash
set -e

dnf update -y

# Zainstaluj tylko runtime biblioteki (NIE kompilatory)
dnf install -y mariadb105 python3-pip unzip

mkdir -p /home/ec2-user/backend
chown ec2-user:ec2-user /home/ec2-user/backend

echo "EC2 setup completed" > /var/log/user-data-complete.log
EOF

  tags = {
    Name = "${var.project_name}-Backend-EC2"
  }
}
