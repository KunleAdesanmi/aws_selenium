provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.11.0"

  name = "ci-cd-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

resource "aws_ecs_cluster" "ci_cd_cluster" {
  name = "ci-cd-cluster"
}

resource "aws_db_instance" "sonarqube_db" {
  identifier         = "sonarqube-db"
  allocated_storage  = 20
  engine             = "postgres"
  engine_version     = "13.4"
  instance_class     = "db.t3.micro"
  name               = "sonar"
  username           = "sonar"
  password           = "sonarpassword"
  parameter_group_name = "default.postgres13"
  skip_final_snapshot = true

  vpc_security_group_ids = [module.vpc.default_security_group_id]
  db_subnet_group_name   = module.vpc.database_subnet_group
}

resource "aws_ecr_repository" "repo" {
  name = "ci-cd-repo"
}

resource "aws_ecs_task_definition" "sonarqube" {
  family                   = "sonarqube-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name      = "sonarqube"
    image     = "${aws_ecr_repository.repo.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 9000
      hostPort      = 9000
    }]
    environment = [
      {
        name  = "SONARQUBE_JDBC_URL"
        value = "jdbc:postgresql://${aws_db_instance.sonarqube_db.address}:5432/sonar"
      },
      {
        name  = "SONARQUBE_JDBC_USERNAME"
        value = "sonar"
      },
      {
        name  = "SONARQUBE_JDBC_PASSWORD"
        value = "sonarpassword"
      }
    ]
  }])
}

resource "aws_ecs_task_definition" "owasp_zap" {
  family                   = "owasp-zap-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name      = "owasp-zap"
    image     = "owasp/zap2docker-stable"
    essential = true
  }])
}

resource "aws_ecs_task_definition" "selenium_grid" {
  family                   = "selenium-grid-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "selenium-hub"
      image     = "selenium/hub"
      essential = true
      portMappings = [{
        containerPort = 4444
        hostPort      = 4444
      }]
    },
    {
      name      = "chrome-node"
      image     = "selenium/node-chrome"
      essential = true
      environment = [{
        name  = "HUB_HOST"
        value = "selenium-hub"
      }]
    },
    {
      name      = "firefox-node"
      image     = "selenium/node-firefox"
      essential = true
      environment = [{
        name  = "HUB_HOST"
        value = "selenium-hub"
      }]
    }
  ])
}

resource "aws_ecs_service" "sonarqube" {
  name            = "sonarqube-service"
  cluster         = aws_ecs_cluster.ci_cd_cluster.id
  task_definition = aws_ecs_task_definition.sonarqube.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [module.vpc.default_security_group_id]
  }
}

resource "aws_ecs_service" "owasp_zap" {
  name            = "owasp-zap-service"
  cluster         = aws_ecs_cluster.ci_cd_cluster.id
  task_definition = aws_ecs_task_definition.owasp_zap.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [module.vpc.default_security_group_id]
  }
}

resource "aws_ecs_service" "selenium_grid" {
  name            = "selenium-grid-service"
  cluster         = aws_ecs_cluster.ci_cd_cluster.id
  task_definition = aws_ecs_task_definition.selenium_grid.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [module.vpc.default_security_group_id]
  }
}
