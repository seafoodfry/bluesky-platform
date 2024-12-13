locals {
  trail_name = "events"
}

#################
### S3 Bucket ###
#################
resource "aws_s3_bucket" "cloudtrail" {
  bucket        = "aws-cloudtrail-logs-${data.aws_caller_identity.current.account_id}-123"
  force_destroy = true
}

# See https://docs.aws.amazon.com/awscloudtrail/latest/userguide/create-s3-bucket-policy-for-cloudtrail.html
data "aws_iam_policy_document" "cloudtrail" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${local.trail_name}"]
    }
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${local.trail_name}"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail.json
}

##################
### Cloudwatch ###
##################
resource "aws_cloudwatch_log_group" "cloudtrail_cloudwatch" {
  name = "cloudtrail"
}

# See https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-required-policy-for-cloudwatch-logs.html
data "aws_iam_policy_document" "cloudtrail_cloudwatch" {
  statement {
    actions   = ["logs:CreateLogStream"]
    resources = ["${aws_cloudwatch_log_group.cloudtrail_cloudwatch.arn}:*"]
  }
  statement {
    actions   = ["logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.cloudtrail_cloudwatch.arn}:*"]
  }
}

resource "aws_iam_policy" "cloudtrail_cloudwatch" {
  name        = "cloudtrail-cloudwatch"
  description = "Policy to send cloudtrail logs to cloudwatch"
  policy      = data.aws_iam_policy_document.cloudtrail_cloudwatch.json
}

resource "aws_iam_role_policy_attachment" "cloudtrail_cloudwatch" {
  role       = aws_iam_role.cloudtrail_cloudwatch.name
  policy_arn = aws_iam_policy.cloudtrail_cloudwatch.arn
}

# See https://docs.aws.amazon.com/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html
data "aws_iam_policy_document" "cloudtrail_cloudwatch_trust_policy" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "cloudtrail_cloudwatch" {
  name               = "cloudtrail-cloudwatch"
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_cloudwatch_trust_policy.json
}

##################
### Cloudtrail ###
##################
resource "aws_cloudtrail" "cloudtrail" {
  depends_on = [aws_s3_bucket_policy.cloudtrail]

  name                          = local.trail_name
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail_cloudwatch.arn}:*" # CloudTrail requires the Log Stream wildcard.
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch.arn

  advanced_event_selector {
    name = "Log management events"
    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
  }
  advanced_event_selector {
    name = "Log all SQS events"
    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }
    field_selector {
      field  = "resources.type"
      equals = ["AWS::SQS::Queue"]
    }
  }
}