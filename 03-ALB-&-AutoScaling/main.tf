# ========================================================
# 1. DATA SOURCES: FETCH DEFAULT NETWORKING
# --------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  # this filter to avoid the t2.micro limitation in ap-south-1c
  filter {
    name   = "availability-zone"
    values = ["ap-south-1a", "ap-south-1b"] #1c doesn't support t2.micro
  }
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-202*-x86_64"]
  }
}

# ========================================================
# 2. SECURITY GROUPS (ALB vs EC2 Instance)
# --------------------------------------------------------

# ALB Security Group (Open to public internet)
resource "aws_security_group" "alb_sg" {
  name        = "portfolio-alb-sg"
  vpc_id      = data.aws_vpc.default.id
  description = "Allow public HTTP traffic to ALB"

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

# Instance Security Group (LOCKED DOWN TO ALB ONLY)
resource "aws_security_group" "instance_sg" {
  name        = "portfolio-instance-sg"
  vpc_id      = data.aws_vpc.default.id
  description = "Allow traffic ONLY from the ALB"

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # Security Group Chaining!
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ========================================================
# 3. APPLICATION LOAD BALANCER (ALB) SETUP
# --------------------------------------------------------
resource "aws_lb" "my_alb" {
  name               = "portfolio-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "my_tg" {
  name     = "portfolio-asg-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_tg.arn
  }
}

# ========================================================
# 4. LAUNCH TEMPLATE & AUTO SCALING GROUP (ASG)
# --------------------------------------------------------
resource "aws_launch_template" "asg_template" {
  name_prefix   = "portfolio-asg-template-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  user_data              = filebase64("${path.module}/userdata.sh")

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "my_asg" {
  name_prefix         = "portfolio-asg-"
  desired_capacity    = var.asg_desired_capacity
  max_size            = var.asg_max_size
  min_size            = var.asg_min_size
  target_group_arns   = [aws_lb_target_group.my_tg.arn]
  vpc_zone_identifier = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.asg_template.id
    version = "$Latest"
  }

  # Tag instances dynamically
  tag {
    key                 = "Name"
    value               = "ASG-Web-Server"
    propagate_at_launch = true
  }
}