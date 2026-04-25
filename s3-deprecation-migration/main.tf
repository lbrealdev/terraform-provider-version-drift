provider "aws" {
  region = var.region
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "logging_target" {
  bucket = "my-access-logs-bucket-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "my-access-logs-bucket"
    Environment = "production"
  }
}

resource "aws_s3_bucket" "main" {
  bucket = "my-app-logs-${random_id.bucket_suffix.hex}"

  force_destroy = false

  # LEGACY/DEPRECATED: These arguments work but generate deprecation warnings
  # in AWS provider v4.0+. They are commented out to show the modern replacement pattern.
  #
  # Arguments below are replaced by:
  #   acl           -> aws_s3_bucket_acl
  #   logging       -> aws_s3_bucket_logging
  #   versioning    -> aws_s3_bucket_versioning
  #   lifecycle_rule-> aws_s3_bucket_lifecycle_configuration
  #
  # Use create_modern_resources=false to use these deprecated arguments (for comparison)
  # Use create_modern_resources=true to use the modern resources below

  # ============================================
  # DEPRECATED ARGUMENTS START HERE
  # ============================================

  # acl = "private"

  # logging {
  #   target_bucket = aws_s3_bucket.logging_target.id
  #   target_prefix = "log/"
  # }

  # versioning {
  #   enabled    = true
  #   mfa_delete = false
  # }

  # lifecycle_rule {
  #   id      = "archive-logs"
  #   enabled = true

  #   prefix = "logs/"

  #   transition {
  #     days          = 30
  #     storage_class = "STANDARD_IA"
  #   }

  #   transition {
  #     days          = 90
  #     storage_class = "GLACIER"
  #   }

  #   expiration {
  #     days = 365
  #   }
  # }

  # ============================================
  # DEPRECATED ARGUMENTS END HERE
  # ============================================

  depends_on = [aws_s3_bucket.logging_target]

  tags = {
    Name        = "my-app-logs"
    Environment = "production"
  }
}

resource "aws_s3_bucket_ownership_controls" "main" {
  count = var.create_modern_resources ? 1 : 0

  bucket = aws_s3_bucket.main.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "main" {
  count = var.create_modern_resources ? 1 : 0

  bucket = aws_s3_bucket.main.id
  acl    = "private"

  depends_on = [
    aws_s3_bucket.main,
    aws_s3_bucket_ownership_controls.main
  ]
}

resource "aws_s3_bucket_logging" "main" {
  count = var.create_modern_resources ? 1 : 0

  bucket = aws_s3_bucket.main.id

  target_bucket = aws_s3_bucket.logging_target.id
  target_prefix = "log/"

  depends_on = [aws_s3_bucket.main, aws_s3_bucket.logging_target]
}

resource "aws_s3_bucket_versioning" "main" {
  count = var.create_modern_resources ? 1 : 0

  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = "Enabled"
  }

  depends_on = [aws_s3_bucket.main]
}

resource "aws_s3_bucket_lifecycle_configuration" "main" {
  count = var.create_modern_resources ? 1 : 0

  bucket = aws_s3_bucket.main.id

  rule {
    id     = "archive-logs"
    status = "Enabled"

    filter {
      prefix = "logs/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }

  depends_on = [aws_s3_bucket.main]
}
