resource "random_pet" "upload_bucket_name" {
  prefix = "upload-bucket"
  length = 2
}

resource "aws_s3_bucket" "upload_bucket" {
  bucket        = random_pet.upload_bucket_name.id
  acl           = "private"
  force_destroy = true
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.sample-drupal-kms-key.key_id
        sse_algorithm     = "aws:kms"
      }
    }
  }
}