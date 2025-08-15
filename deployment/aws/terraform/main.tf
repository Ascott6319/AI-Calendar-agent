# ECS Cluster
resource "aws_ecs_cluster" "ai_calendar_cluster" {
  name = "ai-calendar-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "AI Calendar Agent Cluster"
    Environment = var.environment
  }
}

# Application Load Balancer
resource "aws_lb" "ai_calendar_alb" {
  name               = "ai-calendar-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets           = var.public_subnet_ids

  enable_deletion_protection = var.environment == "production"

  tags = {
    Name        = "AI Calendar ALB"
    Environment = var.environment
  }
}

# ECS Service
resource "aws_ecs_service" "ai_calendar_service" {
  name            = "ai-calendar-service"
  cluster         = aws_ecs_cluster.ai_calendar_cluster.id
  task_definition = aws_ecs_task_definition.ai_calendar_task.arn
  desired_count   = var.desired_count
  
  launch_type         = "FARGATE"
  platform_version    = "LATEST"
  scheduling_strategy = "REPLICA"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ai_calendar_tg.arn
    container_name   = "ai-calendar-agent"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener.ai_calendar_listener]

  tags = {
    Name        = "AI Calendar Service"
    Environment = var.environment
  }
}

# Auto Scaling
resource "aws_appautoscaling_target" "ai_calendar_target" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.ai_calendar_cluster.name}/${aws_ecs_service.ai_calendar_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ai_calendar_up" {
  name               = "ai-calendar-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ai_calendar_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ai_calendar_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ai_calendar_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
