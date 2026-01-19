# Konfiguracja klucza KMS do szyfrowania zasobów
# Klucz jest używany do szyfrowania wolumenów EBS, bazy danych RDS i bucketów S3.
# Polityka klucza nadaje uprawnienia do zarządzania kluczem dla roota konta,
# oraz uprawnienia do używania klucza dla ról IAM (deploy, ec2) i usług (CloudFront).

resource "aws_kms_key" "main" {
  description             = "Klucz KMS dla projektu ${var.project_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "Allow GitHub Actions Deploy Role",
        Effect = "Allow",
        Principal = {
          AWS = aws_iam_role.deploy_role.arn
        },
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ],
        Resource = "*"
      },
      {
        Sid    = "Allow EC2 Role",
        Effect = "Allow",
        Principal = {
          AWS = aws_iam_role.ec2_role.arn
        },
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ],
        Resource = "*"
      },
      {
        Sid    = "Allow CloudFront to use the key",
        Effect = "Allow",
        Principal = {
          Service = "cloudfront.amazonaws.com"
        },
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*"
        ],
        Resource = "*",
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-kms-key"
  }
}

# Alias dla klucza KMS ułatwiający identyfikację
resource "aws_kms_alias" "main" {
  name          = "alias/${var.project_name}-key"
  target_key_id = aws_kms_key.main.key_id
}
