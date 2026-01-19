# Definicje zmiennych wejściowych dla projektu Terraform

variable "aws_region" {
  description = "Region AWS, w którym tworzona jest infrastruktura."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nazwa projektu, używana do tagowania zasobów."
  type        = string
  default     = "projekt-brch"
}

variable "my_ip_cidr" {
  description = "Twój publiczny adres IP w notacji CIDR, dozwolony do SSH do Bastionu."
  type        = string
  sensitive   = false
}

variable "db_name" {
  description = "Nazwa bazy danych."
  type        = string
  default     = "brchdb"
}



