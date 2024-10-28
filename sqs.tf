#Create SQS Queue
resource "aws_sqs_queue" "tech_learning_queue" {
  name = "tech_learning_queue"
}

#Subscribe SQS to SNS Topic
resource "aws_sns_topic_subscription" "sns_sqs_subscription" {
  endpoint = aws_sqs_queue.tech_learning_queue.arn
  protocol = "sqs"
  topic_arn = aws_sns_topic.tech_learning_topic.arn
  raw_message_delivery = true
}

#Grant SQS access to SNS
resource "aws_sqs_queue_policy" "sqs_policy" {
  queue_url = aws_sqs_queue.tech_learning_queue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "SQS:SendMessage"
        Effect = "Allow"
        Principal = "*"
        Resource = aws_sqs_queue.tech_learning_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" : aws_sns_topic.tech_learning_topic.arn
          }
        }
      }
    ]
  })
}
# #Create SNS Topic subscription to Lambda
# # resource "aws_sns_topic_subscription" "sns_lambda_subscription" {
# #   endpoint = aws_lambda_function.tech_learning_lambda.arn
# #   protocol = "lambda"
# #   topic_arn = aws_sns_topic.tech_learning_topic.arn
# # }

# #Allow SNS to invoke Lambda
# # resource "aws_lambda_permission" "allow_sns" {
# #   action = "lambda:InvokeFunction"
# #   function_name = aws_lambda_function.tech_learning_lambda.function_name
# #   principal = "sns.amazonaws.com"
# #   source_arn = aws_sns_topic.tech_learning_topic.arn
# #   statement_id = "AllowExecutionFromSNS"
# # }