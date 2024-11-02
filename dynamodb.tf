#Create DynamoDb table
resource "aws_dynamodb_table" "tech_learning_table" {
  name = "mu-tech-learning"
  hash_key = "id"
  billing_mode   = "PROVISIONED"
  read_capacity = 1
  write_capacity = 1
  attribute {
    name = "id"
    type = "S"
  }
  stream_enabled = true
  stream_view_type = "NEW_IMAGE"
}

#Policy for DynamoDB access
resource "aws_iam_policy" "dynamodb_policy" {
  name        = "dynamodb-policy"
  description = "Policy for DynamoDB access"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "dynamodb:BatchGetItem",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:BatchWriteItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/mu-tech-learning",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "dynamodb_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.dynamodb_policy.arn
}


# Create an IAM Role for DynamoDB Streams to Kinesis
resource "aws_iam_role" "dynamodb_to_kinesis_role" {
  name = "dynamodb-to-kinesis-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "dynamodb.amazonaws.com"
        },
      },
    ],
  })
}

# IAM Policy to allow DynamoDB to put records in Kinesis
resource "aws_iam_policy" "dynamodb_to_kinesis_policy" {
  name = "dynamodb-to-kinesis-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["kinesis:PutRecord", "kinesis:PutRecords","kinesis:DescribeStream"],
        Effect   = "Allow",
        Resource = aws_kinesis_stream.tech-learning_stream.arn
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "attach_dynamodb_to_kinesis_policy" {
  role       = aws_iam_role.dynamodb_to_kinesis_role.name
  policy_arn = aws_iam_policy.dynamodb_to_kinesis_policy.arn
}