# Konfiguracja dystrybucji CloudFront dla frontendu
# Dystrybucja posiada dwa źródła (origins):
# 1. Bucket S3 dla zasobów statycznych (React app).
# 2. Application Load Balancer dla zapytań do API (/api/*).

data "aws_cloudfront_cache_policy" "CachingDisabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "AllViewer" {
  name = "Managed-AllViewer"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.frontend.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "ALB-${aws_lb.main.name}"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for ${var.project_name}"
  price_class         = "PriceClass_100"
  default_root_object = "index.html"

  # Domyślne zachowanie cache
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.frontend.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  ordered_cache_behavior {
    path_pattern             = "/api/*"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    target_origin_id         = "ALB-${aws_lb.main.name}"
    viewer_protocol_policy   = "https-only"
    cache_policy_id          = data.aws_cloudfront_cache_policy.CachingDisabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.AllViewer.id
  }

  # Konfiguracja dla Single Page Application (SPA)
  # Przekierowuje błędy 403 i 404 do /index.html, aby React Router mógł działać
  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
  }

  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
  }

  # Ograniczenia geograficzne (opcjonalne, domyślnie brak)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Użycie darmowego certyfikatu SSL od CloudFront
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.project_name}-cloudfront"
  }
}
