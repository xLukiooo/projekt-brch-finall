# Konfiguracja bazy danych RDS (MySQL)

# Grupa podsieci dla RDS, umieszczająca bazę w podsieciach prywatnych
resource "aws_db_subnet_group" "main" {
  name       = "${lower(var.project_name)}-rds-subnet-group"
  subnet_ids = [for subnet in aws_subnet.private : subnet.id]

  tags = {
    Name = "${var.project_name}-rds-subnet-group"
  }
}

# Losowe, silne hasło dla bazy danych
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Instancja bazy danych RDS MySQL
resource "aws_db_instance" "main" {
  allocated_storage      = 20    # GB, w ramach Free Tier
  storage_type           = "gp2" # General Purpose SSD, w ramach Free Tier
  engine                 = "mysql"
  engine_version         = "8.0.42"
  instance_class         = "db.t3.micro" # Free Tier
  db_name                = var.db_name
  username               = "dbadmin"
  password               = random_password.db_password.result
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  storage_encrypted = true # Szyfrowanie danych w spoczynku
  kms_key_id        = aws_kms_key.main.arn

  publicly_accessible     = false # Brak publicznego dostępu
  backup_retention_period = 7     # Przechowywanie backupów przez 7 dni
  multi_az                = false # Dla Free Tier i celów deweloperskich; w produkcji `true`

  # Pominięcie tworzenia snapshotu przy usuwaniu bazy danych. Użyteczne w środowisku deweloperskim.
  # W środowisku produkcyjnym powinno być ustawione na `false`.
  skip_final_snapshot = true

  tags = {
    Name = "${var.project_name}-RDS-instance"
  }
}
