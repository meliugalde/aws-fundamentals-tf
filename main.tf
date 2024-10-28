terraform {
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "~>5.0"
      }
    }
}

#Configure the aws provider
provider "aws" {
  region = "eu-west-1"
}

# Create an S3 bucket to store transformed data
resource "aws_s3_bucket" "firehose_bucket" {
  bucket = "firehose-transformed-data"
}

# Configure Server-Side Encryption using the new resource
resource "aws_s3_bucket_server_side_encryption_configuration" "firehose_bucket_encryption" {
  bucket = aws_s3_bucket.firehose_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_kinesis_firehose_key.arn
    }
  }
}

# Create a KMS Key
resource "aws_kms_key" "s3_kinesis_firehose_key" {
  description             = "KMS key for S3 bucket encryption for Kinesis Firehose"
  deletion_window_in_days = 10
}