
resource "aws_db_subnet_group" "data_subnet" {
  name                   = "data-subnet"
  subnet_ids             = module.network.aws_subnet_ids.data.ids

  tags = local.common_tags
}

resource "aws_rds_cluster" "mysql" {
  cluster_identifier      = "sample-mysql-cluster-demo"
  engine                  = "aurora-mysql"
  engine_mode             = "serverless"
  database_name           = "sampledrupaldatabase"
  scaling_configuration {
    auto_pause               = true
    max_capacity             = 64
    min_capacity             = 2
    seconds_until_auto_pause = 300
    timeout_action           = "ForceApplyCapacityChange"
  }
  master_username         = local.db_creds.username
  master_password         = local.db_creds.password
  backup_retention_period = 5
  preferred_backup_window = "07:00-09:00"
  db_subnet_group_name    = aws_db_subnet_group.data_subnet.name
  kms_key_id              = aws_kms_key.sample-drupal-kms-key.arn
  storage_encrypted       = true
  vpc_security_group_ids  = [aws_security_group.rds_security_group.id]
  skip_final_snapshot     = true
  final_snapshot_identifier = "sample-drupal-finalsnapshot"

  tags = local.common_tags
}

data "aws_secretsmanager_secret_version" "creds" {  # create this manually
  secret_id = "sample-rds-db-creds"
}

locals {
  db_creds = jsondecode(
    data.aws_secretsmanager_secret_version.creds.secret_string
  )
}
