# Konfiguracja zasobów IAM (Identity and Access Management)

# --- Konfiguracja OIDC dla GitHub Actions ---

# Tworzy zaufanie do GitHub jako dostawcy tożsamości OIDC.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
}

# --- Rola dla wdrażania aplikacji (Frontend/Backend) ---

resource "aws_iam_role" "deploy_role" {
  name = "GitHubActionsDeployRole" # Rola o niskich uprawnieniach
  path = "/system/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com",
            "token.actions.githubusercontent.com:sub" = "repo:xLukiooo/projekt-brch:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "deploy_policy" {
  name        = "${var.project_name}-github-deploy-policy"
  description = "Polityka dla GitHub Actions do wdrażania aplikacji. Nadaje uprawnienia do S3 (upload artefaktów), CloudFront (inwalidacja cache) i SSM (zdalne wykonanie skryptu wdrożeniowego na EC2)."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:PutObject", "s3:ListBucket", "s3:DeleteObject", "s3:GetObject"],
        Resource = [
          aws_s3_bucket.frontend.arn,
          "${aws_s3_bucket.frontend.arn}/*",
          aws_s3_bucket.codedeploy_artifacts.arn,
          "${aws_s3_bucket.codedeploy_artifacts.arn}/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = ["cloudfront:CreateInvalidation", "cloudfront:GetDistributionConfig", "cloudfront:GetInvalidation"],
        Resource = aws_cloudfront_distribution.s3_distribution.arn
      },
      {
        Effect   = "Allow",
        Action   = ["ssm:SendCommand", "ssm:DescribeInstanceInformation", "ec2:DescribeInstances", "ssm:GetCommandInvocation", "ssm:ListCommands", "ssm:ListCommandInvocations"],
        Resource = "*" # Uprawnienia SSM często wymagają "*" dla zasobów
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ],
        Resource = aws_kms_key.main.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "deploy_attach" {
  role       = aws_iam_role.deploy_role.name
  policy_arn = aws_iam_policy.deploy_policy.arn
}

# --- Rola dla Terraform ---

resource "aws_iam_role" "terraform_role" {
  name = "GitHubActionsTerraformRole" # Rola o wysokich uprawnieniach
  path = "/system/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com",
            "token.actions.githubusercontent.com:sub" = "repo:xLukiooo/projekt-brch:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}

# Przypisanie polityki Administratora do roli Terraform.
# To daje Terraformowi uprawnienia do zarządzania zasobami w AWS.
resource "aws_iam_role_policy_attachment" "terraform_admin_attach" {
  role       = aws_iam_role.terraform_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# --- Rola IAM dla instancji EC2 backendu ---

resource "aws_iam_policy" "ec2_cloudwatch_policy" {
  name        = "${var.project_name}-ec2-cloudwatch-policy"
  description = "Allows EC2 instance to push logs and metrics to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow",
        Action   = "cloudwatch:PutMetricData",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"
  path = "/system/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "ec2.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_cloudwatch_policy.arn
}

# Dołączenie polityki SSM do roli EC2, aby umożliwić zarządzanie przez Systems Manager.
resource "aws_iam_role_policy_attachment" "ec2_ssm_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# --- Dodatkowe uprawnienia dla roli EC2 backendu ---

# Polityka pozwalająca instancji EC2 na pobieranie artefaktów wdrożeniowych z S3.
resource "aws_iam_policy" "ec2_s3_policy" {
  name        = "${var.project_name}-ec2-s3-policy"
  description = "Allows EC2 instance to get deployment artifacts from S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:GetObject", "s3:ListBucket"],
        Resource = [
          aws_s3_bucket.codedeploy_artifacts.arn,
          "${aws_s3_bucket.codedeploy_artifacts.arn}/*"
        ]
      }
    ]
  })
}

# Dołączenie nowej polityki S3 do roli EC2.
resource "aws_iam_role_policy_attachment" "ec2_s3_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_s3_policy.arn
}
