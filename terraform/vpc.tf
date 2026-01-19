# Konfiguracja sieci VPC, podsieci, bram, tabel routingu

# Pobranie dostępnych stref AZ w regionie
data "aws_availability_zones" "available" {}

# Tworzenie VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-VPC"
  }
}

# Utworzenie 2 podsieci publicznych w różnych Strefach Dostępności (AZ)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${1 + count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-PublicSubnet-${count.index + 1}"
  }
}

# Utworzenie 2 podsieci prywatnych w różnych Strefach Dostępności (AZ)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${101 + count.index}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-PrivateSubnet-${count.index + 1}"
  }
}

# Internet Gateway dla ruchu wychodzącego z podsieci publicznych
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-IGW"
  }
}

# Tabela routingu dla podsieci publicznych (ruch do internetu przez IGW)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-PublicRouteTable"
  }
}

# Tabela routingu dla podsieci prywatnych (pozostaje bez domyślnej trasy do internetu)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-PrivateRouteTable"
  }
}

# --- Konfiguracja VPC Endpoints ---

# Endpoint typu Gateway dla S3. Umożliwia dostęp do S3 (np. repozytoriów yum i artefaktów)
# z podsieci prywatnych bez wychodzenia do internetu, co zwiększa bezpieczeństwo i obniża koszty.
# Jest to usługa darmowa.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "${var.project_name}-s3-endpoint"
  }
}

# Grupa bezpieczeństwa dla Interface Endpoints (SSM)
# Pozwala na ruch HTTPS z zasobów wewnątrz VPC.
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project_name}-vpc-endpoints-sg"
  description = "Allow HTTPS from within the VPC to interface endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    description = "Allow outbound traffic within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {
    Name = "${var.project_name}-vpc-endpoints-sg"
  }
}

# Endpointy typu Interface dla AWS Systems Manager (SSM).
# Niezbędne do działania agenta SSM na instancjach w podsieciach prywatnych.
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "${var.project_name}-ssm-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "${var.project_name}-ssmmessages-endpoint"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "${var.project_name}-ec2messages-endpoint"
  }
}

# Powiązanie tabeli routingu z podsieciami publicznymi
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Powiązanie tabeli routingu z podsieciami prywatnymi
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
