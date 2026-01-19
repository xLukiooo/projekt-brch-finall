# Konfiguracja bucketu S3 dla hostingu statycznej strony (React)


# Bucket S3 dla statycznej strony frontendowej
resource "aws_s3_bucket" "frontend" {
  bucket = "${lower(var.project_name)}-frontend-bucket"
}

# DODAJ TO:
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.project_name}-oac"
  description                       = "OAC for ${var.project_name} frontend bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Nowy bucket S3 na artefakty wdrożeniowe backendu
resource "aws_s3_bucket" "codedeploy_artifacts" {
  bucket = "${lower(var.project_name)}-codedeploy-artifacts"
}

# Szyfrowanie po stronie serwera (SSE) dla bucketu S3 z artefaktami
resource "aws_s3_bucket_server_side_encryption_configuration" "codedeploy_artifacts_encryption" {
  bucket = aws_s3_bucket.codedeploy_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
  }
}

# Włączenie wersjonowania na buckecie S3
resource "aws_s3_bucket_versioning" "codedeploy_artifacts_versioning" {
  bucket = aws_s3_bucket.codedeploy_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Włączenie wersjonowania na buckecie S3
resource "aws_s3_bucket_versioning" "frontend_versioning" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Szyfrowanie po stronie serwera (SSE) dla bucketu S3 przy użyciu klucza KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend_encryption" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
  }
}

# Blokada publicznego dostępu do bucketu S3
resource "aws_s3_bucket_public_access_block" "frontend_block_public" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Polityka bucketu S3, która zezwala na dostęp do obiektów tylko dla CloudFront.
# Używa OAC (Origin Access Control) zamiast przestarzałego OAI (Origin Access Identity).
resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow",
        Principal = {
          Service = "cloudfront.amazonaws.com"
        },
        Action   = "s3:GetObject",
        Resource = "${aws_s3_bucket.frontend.arn}/*",
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
          }
        }
      }
    ]
  })
}

# Konfiguracja CORS na buckecie S3
# Zezwala na żądania tylko z domeny CloudFront
resource "aws_s3_bucket_cors_configuration" "frontend_cors" {
  bucket = aws_s3_bucket.frontend.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["https://${aws_cloudfront_distribution.s3_distribution.domain_name}"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Losowy sufix dla nazwy bucketu, aby zapewnić unikalność
resource "random_id" "bucket_suffix" {
  byte_length = 4
}
