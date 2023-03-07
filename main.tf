terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}


provider "aws" {
  region                   = "sa-east-1"
  shared_config_files      = ["~/.aws/conf"]
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "vscode"
}

resource "aws_s3_bucket" "test" {

  bucket_prefix = "fileset-testing"
}

resource "aws_s3_bucket_policy" "public_read_access" {
  bucket = aws_s3_bucket.test.id
  policy = data.aws_iam_policy_document.public_read_access.json
}

data "aws_iam_policy_document" "public_read_access" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.test.arn,
      "${aws_s3_bucket.test.arn}/*",
    ]
  }
}

locals {
  mime_types = jsondecode(file("${path.module}/data/mime.json"))
}


resource "aws_s3_object" "test" {
  for_each = fileset("${path.module}/s3Content", "**/*")

  bucket       = aws_s3_bucket.test.id
  key          = each.value
  source       = "${path.module}/s3Content/${each.value}"
  content_type = lookup(local.mime_types, regex("\\.[^.]+$", each.value), null)
  content_disposition = "inline"
  content_encoding = "UTF8"
  etag         = filemd5("${path.root}/s3Content/${each.value}")

}

resource "aws_s3_bucket_public_access_block" "test" {
  bucket = aws_s3_bucket.test.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

output "fileset-results" {
  value = fileset(path.module, "**/*")
}