# ========= variables ==========

variable "ecr_repo" {
  description = "The root URL of the ECR repository of the application"
  type        = string
  default     = "206396035828.dkr.ecr.eu-west-3.amazonaws.com"
}

variable "ecr_image" {
  description = "The image name in the ECR repository to use for starting the service"
  type        = string
  default     = "206396035828.dkr.ecr.eu-west-3.amazonaws.com"
}

variable "ecs_role" {
  description = "The name of the role to be assumed by ECS tasks"
  type        = string
  default     = "EcsTaskExecutionRole"
}

variable "app_port" {
  description = "The port where it runs the qubec API server"
  default     = 8000
}

variable "profile" {
  description = "The AWS profile configured locally"
  type        = string
  default     = "default"
}

variable "region" {
  description = "The AWS region where to start the ECS service"
  type        = string
  default     = "us-east-1"
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ========= providers ==========

provider "aws" {
  region  = var.region
  profile = var.profile
}

# ========= resources ==========

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.48.0"

  name = "sample_vpc"
  cidr = "10.0.0.0/16"

  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_ipv6          = false
  enable_nat_gateway   = true
  enable_vpn_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name      = "basic-example-vpc"
    Terraform = "true"
  }
}

# resource "aws_service_discovery_private_dns_namespace" "example_namespace" {
#   name        = "sample_app"
#   description = "Service discovery test"
#   vpc         = module.vpc.vpc_id
# }

data "aws_iam_policy_document" "ecs_task_execution_role" {
  version = "2012-10-17"
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com", "ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = var.ecs_role
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# resource "aws_iam_role_policy_attachment" "ecs_ec2_container_policy" {
#   role       = aws_iam_role.ecs_execution.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
# }

# resource "aws_iam_instance_profile" "ecs_instance" {
#   name = var.ecs_role
#   role = aws_iam_role.ecs_execution.name
# }

resource "aws_ecs_cluster" "example_cluster" {
  name = "basic-example-cluster"
}

# ========= service ==========

module "sample_app" {

  source = "../../"

  ecs_cluster     = aws_ecs_cluster.example_cluster.id
  task_name       = "sample_app"
  container_image = "${var.ecr_repo}/${var.ecr_image}"
  task_exec_role  = aws_iam_role.ecs_execution.arn

  vpc_id          = module.vpc.vpc_id
  vpc_subnets     = module.vpc.private_subnets
  security_groups = [module.vpc.default_security_group_id]

  task_launch_type  = "FARGATE"
  task_network_mode = "awsvpc"
  open_ports        = [var.app_port]
  environment = [
    {
      "name" : "EXAMPLE_ENV"
      "value" : "sample"
    }
  ]
}
