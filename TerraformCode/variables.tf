variable "bucket_name" {
  description = "S3 main bucket name"
  type        = string
  default = "mainbucketxav519"
}
variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}