resource "aws_db_instance" "flowise" {
  allocated_storage    = var.db_storage
  storage_type         = var.db_storage_type
  instance_class       = var.db_storage_class
  identifier           = var.db_identifier
  engine               = var.db_engine
  engine_version       = var.db_engine_version

  db_name  = var.db_name
  username = var.db_user
  password = var.db_pass

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_security_group.id]
  skip_final_snapshot    = true

  tags = {
    Name = "RDS Instance"
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.private1.id, aws_subnet.private2.id]
}

# RDS security group
resource "aws_security_group" "rds_security_group" {
  name        = "rds-security-group"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.100.0.0/16"]
  }


  tags = {
    Name = "RDS Security Group"
  }
}

#Create Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Security group for ALB"
  
  vpc_id = "vpc-0efc01cc9b85be06b"  

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create ALB
resource "aws_lb" "my_alb_2" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  
  subnets = [
    "subnet-068e02d8fe638d3aa",  
    "subnet-014140738f5c0a5da"   
  ]
}

# Create Target Group
resource "aws_lb_target_group" "my_target_group_2" {
  name     = "my-target-group-2"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = "vpc-0efc01cc9b85be06b"  
  
  target_type = "ip"
}

# Create Listener
resource "aws_lb_listener" "my_listener_2" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_target_group.arn
  }
}

# Create ECS Cluster
resource "aws_ecs_cluster" "my_cluster" {
  name = "my-cluster"
}

# Create ECS Task Definition
resource "aws_ecs_task_definition" "flowise_task" {
  family                   = "flowise-task"
  cpu                      = "256"
  memory                   = "512"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  container_definitions = jsonencode([
    {
      name            = "app"
      image           = "flowiseai/flowise:1.4.3"
      cpu             = 256
      memory          = 512
      essential       = true
      command         = ["/bin/sh", "-c", "sleep 3 && flowise start"]
      portMappings    = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "DB_NAME"
          value = "flowise"
        },
        {
          name  = "DB_HOST"
          value = "flowise.craco6s4yp03.us-east-1.rds.amazonaws.com"
        },
        {
          name  = "DB_PORT"
          value = "5432"
        },
        {
          name  = "DB_USER"
          value = "postgres"
        },
        {
          name  = "DB_PASSWORD"
          value = "admin1234"
        }
      ]
      mount_points = [
        {
          source_volume  = "flowise-volume"
          container_path = "/root/.flowise"
          read_only      = false
        }
      ]
      volumes_from = []
    }
  ])

  volume {
    name = "flowise-volume"
  }
}

# Create ECS Service
resource "aws_ecs_service" "flowise_service" {
  name            = "flowise-service"
  cluster         = aws_ecs_cluster.my_cluster.id
  task_definition = aws_ecs_task_definition.flowise_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = ["subnet-068e02d8fe638d3aa", "subnet-014140738f5c0a5da"]  
    security_groups  = ["sg-020f64393c5f56a2f"]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.my_target_group.arn
    container_name   = "app"
    container_port   = 3000  
  }
}

# Output ECS Task Definition ARN
output "flowise_task_arn" {
  value = aws_ecs_task_definition.flowise_task.arn
}