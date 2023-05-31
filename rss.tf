resource "aws_sqs_queue" "cabrio_queue" {
  name = "cabrio-resp"
}

data "aws_iam_policy_document" "cabrio_policy" {
  statement {
    sid    = "Cabrio Queue"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.cabrio_queue.arn]
  }
}

resource "aws_sqs_queue_policy" "cabrio_policies" {
  queue_url = aws_sqs_queue.cabrio_queue.id
  policy    = data.aws_iam_policy_document.cabrio_policy.json
}
