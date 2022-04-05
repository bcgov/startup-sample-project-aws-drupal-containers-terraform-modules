# ecs.tf

resource "aws_ecs_cluster" "main" {
  name               = "sample-cluster"
  capacity_providers = ["FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
  }

  tags = local.common_tags
}

resource "aws_ecs_task_definition" "app" {
  count                    = local.create_ecs_service
  family                   = "sample-app-task"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.sample_app_container_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  tags                     = local.common_tags
  volume {
    name = "themes"
    efs_volume_configuration  {
        file_system_id = aws_efs_file_system.sample-drupal.id
        transit_encryption = "ENABLED"
        authorization_config {
          iam = "ENABLED"
          access_point_id = aws_efs_access_point.themes.id
        }
    }
  }
  volume {
    name = "profiles"
    efs_volume_configuration  {
        file_system_id = aws_efs_file_system.sample-drupal.id
        transit_encryption = "ENABLED"      
        authorization_config {
          iam = "ENABLED"
          access_point_id = aws_efs_access_point.profiles.id
        }
    }
  }
  volume {
    name = "sites"
    efs_volume_configuration  {
        file_system_id = aws_efs_file_system.sample-drupal.id
        transit_encryption = "ENABLED"        
        authorization_config {
          iam = "ENABLED"
          access_point_id = aws_efs_access_point.sites.id
        }
    }
  }
  volume {
    name = "modules"
    efs_volume_configuration  {
        file_system_id = aws_efs_file_system.sample-drupal.id
        transit_encryption = "ENABLED"        
        authorization_config {
          iam = "ENABLED"
          access_point_id = aws_efs_access_point.modules.id
        }
    }
  }
  
  container_definitions = jsonencode([
    {
      essential   = false
      name        = "initcontainer"
      image       = var.app_image
      #cpu         = var.fargate_cpu
      #memory      = var.fargate_memory
      networkMode = "awsvpc"
      entryPoint = ["sh", "-c", "cp -prR /var/www/html/sites/* /mnt"]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group  = "true"
          awslogs-group         = "/ecs/${var.app_name}"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      mountPoints = [
        {
          containerPath = "/mnt"
          sourceVolume = "sites"
        }
      ]
      volumesFrom = []
    },
    {
      dependsOn = [{
        condition = "COMPLETE"
        containerName = "initcontainer"
      }]
      essential   = true
      name        = var.container_name
      image       = var.app_image
      #cpu         = var.fargate_cpu
      #memory      = var.fargate_memory
      networkMode = "awsvpc"
      portMappings = [
        {
          protocol      = "tcp"
          containerPort = var.app_port
          hostPort      = var.app_port
        },
        {
          protocol      = "tcp"
          containerPort = 8443
          hostPort      = 8443
        }
      ]
      secrets = [
         {
          name  = "MYSQL_USER",
          valueFrom = "${data.aws_secretsmanager_secret_version.creds.arn}:username::"
        },
         {
          name  = "MYSQL_PASSWORD",
          valueFrom = "${data.aws_secretsmanager_secret_version.creds.arn}:password::"
        },           
         {
          name  = "MYSQL_ROOT_PASSWORD",
          valueFrom = "${data.aws_secretsmanager_secret_version.creds.arn}:password::"
        }
      ]
      environment = [
        # {
        #   name  = "DB_NAME"
        #   value = var.db_name
        # },
        {
          name  = "AWS_REGION",
          value = var.aws_region
        },
        {
          name  = "bucketName",
          value = aws_s3_bucket.upload_bucket.id
        },
        # {
        #   name  = "DRUPAL_DATABASE_HOST",
        #   value = aws_rds_cluster.mysql.endpoint
        # },
      
      # {
      #     name  = "DRUPAL_DATABASE_NAME",
      #     value = "sampledrupaldatabase"
      #   },
      #   {
      #     name  = "DRUPAL_SKIP_BOOTSTRAP",
      #     value = "yes"
      #   },
      #     {
      #     name  = "MYSQL_CLIENT_DATABASE_HOST",
      #     value = aws_rds_cluster.mysql.endpoint
      #   },
      #   {
      #     name  = "MYSQL_CLIENT_DATABASE_ROOT_USER",
      #     value = local.db_creds.username
      #   },
      #    {
      #     name  = "MYSQL_CLIENT_DATABASE_ROOT_PASSWORD",
      #     value = local.db_creds.password
      #   },
      # {
      #     name  = "MYSQL_CLIENT_CREATE_DATABASE_NAME",
      #     value = "sampledrupaldatabase"
      #   },
      #    {
      #     name  = "MYSQL_CLIENT_FLAVOR",
      #     value = "mysql"
      #   }
      {
        name   = "MYSQL_DATABASE",
        value  = "drupal"
      },
       {
        name   = "DRUPAL_TRUSTED_HOST",
        value  = "startup-sample-drupal-dev4\\.octank\\.ca"
      }

      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group  = "true"
          awslogs-group         = "/ecs/${var.app_name}"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      mountPoints = [
        {
          containerPath = "/var/www/html/modules/"
          sourceVolume = "modules"
        },
        {
          containerPath = "/var/www/html/sites/"
          sourceVolume = "sites"
        },
        {
          containerPath = "/var/www/html/profiles"
          sourceVolume = "profiles"
        },
        {
          containerPath = "/var/www/html/themes/"
          sourceVolume = "themes"
        }
      ]
      volumesFrom = []
    }
  ])
}

resource "aws_ecs_service" "main" {
  count                             = local.create_ecs_service
  name                              = "sample-service"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.app[count.index].arn
  desired_count                     = var.app_count
  enable_ecs_managed_tags           = true
  propagate_tags                    = "TASK_DEFINITION"
  health_check_grace_period_seconds = 60
  wait_for_steady_state             = false
  enable_execute_command            = true


  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
  }


  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = module.network.aws_subnet_ids.app.ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_drupal.id
    container_name   = var.container_name
    container_port   = var.app_port
  }

  depends_on = [aws_lb_listener.front_end, aws_iam_role_policy_attachment.ecs_task_execution_role]

  tags = local.common_tags
}