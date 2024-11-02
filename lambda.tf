#Create Lambda function
resource "aws_lambda_function" "tech_learning_lambda" {
  function_name = "mu-tech-learning-lambda"
  role = "${aws_iam_role.lambda_role.arn}"
  runtime = "dotnet8"
  filename = "MyLambdaSQS/myLambdaSQS/src/myLambdaSQS/lambda_function.zip"
  memory_size   = 256     # Default is 128 MB, you can increase it
  timeout       = 30      # Timeout in seconds (default is 3 seconds)
  handler       = "myLambdaSQS::myLambdaSQS.Function::FunctionHandler"
  # environment {
  #   variables = {
  #     DYNAMODB_TABLE = aws_dynamodb_table.tech_learning_table.arn
  #   }
  # }
  # depends_on = [aws_cloudwatch_log_group.lambda_log_group]
}


#Create IAM Role for Lambda to allow CloudWatch and DynamoDB access
resource "aws_iam_role" "lambda_role" {
  name = "mu-tech-learning-lambda_role"
  assume_role_policy = jsonencode({
    "Version" = "2012-10-17"
    "Statement" = [
      {
        "Action" = "sts:AssumeRole"
        "Effect" = "Allow"
        "Sid" = ""
        "Principal" = {
          "Service" = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Define the policy document
resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda-dynamodb-cloudwatch-policy"
  description = "Policy for Lambda to access DynamoDB and CloudWatch"

  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect": "Allow",
        "Action": [
          "sqs:ChangeMessageVisibility",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ReceiveMessage"
        ],
        "Resource": "${aws_sqs_queue.tech_learning_queue.arn}"
      },
      # {
      #   "Sid": "AllowInvokingLambdas",
      #   "Effect": "Allow",
      #   "Action": [
      #     "lambda:InvokeFunction"
      #   ],
      #   "Resource": "${aws_lambda_function.tech_learning_lambda.arn}"
      # }
      # {
      #   Action = [
      #     "dynamodb:BatchGetItem",
      #     "dynamodb:GetItem",
      #     "dynamodb:Query",
      #     "dynamodb:Scan",
      #     "dynamodb:BatchWriteItem",
      #     "dynamodb:PutItem",
      #     "dynamodb:UpdateItem"
      #   ]
      #   Resource = "arn:aws:dynamodb:*:*:table/your-table-name"
      #   Effect    = "Allow"
      # },
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
        Effect    = "Allow"
      }
    ]
  })
}

# Attach the policy to the Lambda role
resource "aws_iam_role_policy_attachment" "lambda_attach_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Event source from SQS
resource "aws_lambda_event_source_mapping" "event_source_mapping" {
  event_source_arn = aws_sqs_queue.tech_learning_queue.arn
  enabled          = true
  function_name    = "${aws_lambda_function.tech_learning_lambda.arn}"
  batch_size       = 1
}

resource "aws_iam_policy" "cloudwatch_logs_policy" {
  name        = "cloudwatch-logs-policy"
  description = "Policy for CloudWatch Logs access"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.cloudwatch_logs_policy.arn
}

#Create CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name = "lambda/tech-learning-lambda"
  retention_in_days = 14
}

# Lambda Function for Kinesis Firehose transformation
resource "aws_lambda_function" "firehose_transformation_lambda" {
  function_name = "mu-transformation-lambda"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "transformation_lambda.handler"
  runtime       = "nodejs16.x"
  filename      = "Transformation_lambda/transformation_lambda.zip"  # Path to zipped JS file
  source_code_hash = filebase64sha256("Transformation_lambda/transformation_lambda.zip")

  # Ensure any changes to the code trigger an update
  lifecycle {
    create_before_destroy = true
  }
}


# Lambda Execution Role for Firehose Transformer
resource "aws_iam_role" "lambda_exec_role" {
  name = "mu_lambda_exec_role"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  })
}

# Attach Permissions to the Role  VALID
resource "aws_iam_policy_attachment" "lambda_policy_attachment" {
  name       = "lambda_basic_execution_policy"
  roles      = [aws_iam_role.lambda_exec_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM Policy for Lambda Role
# resource "aws_iam_policy" "lambda_exec_policy" {
#   name   = "lambda_exec_policy"
#   policy = jsonencode({
#     "Version": "2012-10-17",
#     "Statement": [
#       {
#         "Effect": "Allow",
#         "Action": "logs:*",
#         "Resource": "arn:aws:logs:*:*:*"
#       },
#       {
#         "Effect": "Allow",
#         "Action": [
#           "dynamodb:*"
#         ],
#         "Resource": "${aws_dynamodb_table.tech_learning_table.arn}"
#       },
#       {
#         Effect = "Allow",
#         Action = [
#           "kinesis:GetRecords",
#           "kinesis:GetShardIterator",
#           "kinesis:DescribeStream",
#           "kinesis:ListStreams"
#         ],
#         Resource = "${aws_kinesis_stream.tech-learning_stream.arn}"
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "lambda_exec_policy_attach" {
#   role       = aws_iam_role.lambda_exec_role.name
#   policy_arn = aws_iam_policy.lambda_exec_policy.arn
# }

# resource "aws_lambda_event_source_mapping" "dynamodb_stream_to_lambda" {
#   event_source_arn = aws_dynamodb_table.tech_learning_table.stream_arn
#   function_name    = "${aws_lambda_function.firehose_transformer.arn}"
#   enabled          = true
#   batch_size       = 1
#  // starting_position = "LATEST"
# }