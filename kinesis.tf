# Kinesis Data Stream
resource "aws_kinesis_stream" "tech-learning_stream" {
  name        = "tech-learning-stream"
  shard_count = 1

}

# Kinesis Firehose Delivery Stream
resource "aws_kinesis_firehose_delivery_stream" "firehose_stream" {
  name        = "tech-learning-firehose"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.firehose_bucket.arn
    buffering_interval  = 300      # Buffer time in seconds
    buffering_size      = 5        # Buffer size in MB
    compression_format  = "GZIP"   # Compression format for S3 storage

     # Lambda Transformation
    processing_configuration {
      enabled = true

      processors {
        type = "Lambda"

        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = aws_lambda_function.firehose_transformation_lambda.arn
        }
      }
    }

    
    # Reference the KMS key for server-side encryption in the S3 bucket
    s3_backup_configuration {
      role_arn   = aws_iam_role.firehose_role.arn
      bucket_arn = aws_s3_bucket.firehose_bucket.arn

      cloudwatch_logging_options {
        enabled         = true
        log_group_name  = "/aws/kinesisfirehose/tech_leraning_firehose_stream"
        log_stream_name = "S3Backup_tech_learning"
      }
    }
  }

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.tech-learning_stream.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }

 
}

 #IAM role for kinesis
  resource "aws_iam_role" "firehose_role" {
    name = "firehose_delivery_role"

    assume_role_policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service" : "firehose.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
      ]
    })
  }

# IAM Policy for Kinesis Firehose Role
resource "aws_iam_policy" "firehose_policy" {
  name   = "firehose_policy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:ListBucket",
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucketMultipartUploads",
        ],
        "Resource": [
          "${aws_s3_bucket.firehose_bucket.arn}",
          "${aws_s3_bucket.firehose_bucket.arn}/*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
            "kinesis:DescribeStream",
            "kinesis:GetShardIterator",
            "kinesis:GetRecords",
            "kinesis:ListShards"
        ],
        "Resource": "${aws_kinesis_stream.tech-learning_stream.arn}"
      },
      {
        "Effect": "Allow",
        "Action": "lambda:InvokeFunction",
        "Resource": "${aws_lambda_function.firehose_transformation_lambda.arn}"
      },
      {
        "Action" = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:GenerateDataKey"
        ],
        "Effect"   = "Allow",
        "Resource" = aws_kms_key.s3_kinesis_firehose_key.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "firehose_policy_attach" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_policy.arn
}

resource "aws_iam_policy" "put_record" {
  name_prefix = "put-record-firehose"
  policy      = <<-EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "firehose:PutRecord",
                "firehose:PutRecordBatch"
            ],
            "Resource": [
                "${aws_kinesis_firehose_delivery_stream.firehose_stream.arn}"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "put_record" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.put_record.arn
}

resource "aws_dynamodb_kinesis_streaming_destination" "example" {
  stream_arn = aws_kinesis_stream.tech-learning_stream.arn
  table_name = aws_dynamodb_table.tech_learning_table.name
  
}