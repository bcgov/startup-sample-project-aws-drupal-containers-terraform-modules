# startup-sample-project-aws-drupal-containers-terraform-modules

Sample terraform to support a Drupal ECS deployment

Review *db.tf* as it expects a Secret to contain DB credentails that will be used for the RDS deployment. The DB secret is expected to be named 'sample-rds-db-creds'.