# Konfiguracja polityki backupowej dla wolumenów EBS

# Rola IAM dla usługi DLM (Data Lifecycle Manager)
resource "aws_iam_role" "dlm_role" {
  name = "${var.project_name}-dlm-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "dlm.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

# Polityka IAM dla roli DLM, nadająca uprawnienia do zarządzania snapshotami
resource "aws_iam_role_policy" "dlm_policy" {
  name = "${var.project_name}-dlm-policy"
  role = aws_iam_role.dlm_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateSnapshot",
        "ec2:CreateSnapshots",
        "ec2:DeleteSnapshot",
        "ec2:DescribeInstances",
        "ec2:DescribeVolumes",
        "ec2:DescribeSnapshots"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateTags"
      ],
      "Resource": "arn:aws:ec2:*::snapshot/*"
    }
  ]
}
EOF
}

# Polityka cyklu życia DLM
# Tworzy snapshoty codziennie o 02:00 UTC dla wolumenów z tagiem Backup=true i przechowuje je przez 7 dni.
resource "aws_dlm_lifecycle_policy" "ebs_backup" {
  description        = "Daily snapshots for EBS volumes tagged for backup"
  execution_role_arn = aws_iam_role.dlm_role.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    target_tags = {
      "Backup" = "true"
    }

    schedule {
      name = "DailySnapshots"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["02:00"] # Czas w UTC
      }

      retain_rule {
        count = 7 # Przechowuj 7 ostatnich kopii (7 dni)
      }

      tags_to_add = {
        "SnapshotCreator" = "DLM"
      }

      copy_tags = true
    }
  }
}
