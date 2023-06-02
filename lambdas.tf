data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "asterios_rb_lambda_role" {
  name               = "asterios_rb_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "asterios_rb_lambda_policy" {
  role       = aws_iam_role.asterios_rb_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.parse_rss.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.rbs_info.arn
}

locals {
  lambda_code_path    = "${path.module}/lambdas/asterios_rbs"
  lambda_archive_path = "${path.module}/lambdas/asterios_rbs.zip"
  lambda_handler      = "main.invoke"
  lambda_runtime      = "python3.9"
}

resource "random_string" "r" {
  length  = 16
  special = false
}

data "archive_file" "simple_lambda_zip" {
  depends_on  = [null_resource.install_python_dependencies]
  type        = "zip"
  source_dir  = local.lambda_code_path
  output_path = local.lambda_archive_path
}

resource "aws_lambda_function" "parse_rss" {
  source_code_hash = data.archive_file.simple_lambda_zip.output_base64sha256
  filename         = data.archive_file.simple_lambda_zip.output_path
  function_name    = "parse_rss"
  role             = aws_iam_role.asterios_rb_lambda_role.arn
  handler          = local.lambda_handler
  runtime          = local.lambda_runtime
  depends_on       = [null_resource.install_python_dependencies]
}

resource "aws_s3_bucket" "rbs_info" {
  bucket = "asterios-rbs"
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.rbs_info.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.parse_rss.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "AWSLogs/"
    filter_suffix       = ".log"
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}


resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "schedule"
  description         = "Schedule for Lambda Function"
  schedule_expression = var.schedule
}

resource "aws_cloudwatch_event_target" "schedule_lambda" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  target_id = "parse_rss"
  arn       = aws_lambda_function.parse_rss.arn
}


resource "aws_lambda_permission" "allow_events_bridge_to_run_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.parse_rss.function_name
  principal     = "events.amazonaws.com"
}

resource "null_resource" "install_python_dependencies" {
  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/create_pkg.sh"

    environment = {
      source_code_path = local.lambda_code_path
      function_name    = "parse_rss"
      path_module      = path.module
      runtime          = local.lambda_runtime
      path_cwd         = path.cwd
    }
  }
}