provider "aws" {
  region = var.region
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "example" {
  bucket = "my-app-logs-${random_id.bucket_suffix.hex}"

  acl           = "private"
  force_destroy = false

  logging {
    target_bucket = "my-access-logs-bucket"
    target_prefix = "log/"
  }

  versioning {
    enabled    = true
    mfa_delete = false
  }

  lifecycle_rule {
    id      = "archive-logs"
    enabled = true

    prefix = "logs/"

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

  tags = {
    Name        = "my-app-logs"
    Environment = "production"
  }
}

resource "aws_s3_bucket_acl" "example" {
  count = var.create_modern_resources ? 1 : 0

  bucket = aws_s3_bucket.example.id
  acl    = "private"
}

resource "aws_s3_bucket_logging" "example" {
  count = var.create_modern_resources ? 1 : 0

  bucket = aws_s3_bucket.example.id

  target_bucket = "my-access-logs-bucket"
  target_prefix = "log/"
}

resource "aws_s3_bucket_versioning" "example" {
  count = var.create_modern_resources ? 1 : 0

  bucket = aws_s3_bucket.example.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "example" {
  count = var.create_modern_resources ? 1 : 0

  bucket = aws_s3_bucket.example.id

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
}

resource "aws_s3_bucket" "logging_target" {
  count = var.create_modern_resources ? 1 : 0

  bucket = "my-access-logs-bucket"

  tags = {
    Name        = "my-access-logs-bucket"
    Environment = "production"
  }
}
