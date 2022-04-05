resource "aws_kms_key" "sample-drupal-kms-key" {
  description             = "KMS Key for Sample Drupal app"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  tags = local.common_tags
}