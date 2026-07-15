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

  # This filter avoids the t2.micro limitation in ap-south-1c
  filter {
    name   = "availability-zone"
    values = ["ap-south-1a", "ap-south-1b"] # 1c doesn't support t2.micro
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
resource "aws_security_group" "alb_securitygroup" {
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
    protocol    = -1
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
    security_groups = [aws_security_group.alb_securitygroup.id] # Security Group Chaining!
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
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
  security_groups    = [aws_security_group.alb_securitygroup.id]
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
  port              = 80
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

  tag {
    key                 = "Name"
    value               = "ASG-Web-Server"
    propagate_at_launch = true
  }
}

# ========================================================
# 5. WEB APPLICATION FIREWALL (WAFv2) SETUP
# ========================================================
resource "aws_wafv2_web_acl" "my_waf" {
  name        = "portfolio-web-waf"
  description = "Protects ALB from common vulnerabilities and malicious headers"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # RULE 1: AWS Managed Core Rule Set
  rule {
    name     = "AWS-AmazonIpReputationList"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAmazonIpReputationListMetric"
      sampled_requests_enabled   = true
    }
  }

# RULE 2: Custom Rule to Block Malicious Header
  rule {
    name     = "BlockMaliciousHeaderRule"
    priority = 2

    action {
      block {
        custom_response {
          response_code            = 403
          custom_response_body_key = "blocked_by_waf_msg"
        }
      }
    }

    statement {
      byte_match_statement {
        positional_constraint = "EXACTLY" 
        search_string         = "True"

        field_to_match {
          single_header {
            name = "x-hacker-agent"
          }
        }
        
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockMaliciousHeaderMetric"
      sampled_requests_enabled   = true
    }
  }

  custom_response_body {
    key          = "blocked_by_waf_msg"
    content_type = "TEXT_PLAIN"
    content      = "Access Denied: Request blocked by Enterprise AWS WAF. 🛑"
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "PortfolioWAFGlobalMetric"
    sampled_requests_enabled   = true
  }
}

# ========================================================
# 6. ASSOCIATE WAF WITH THE APPLICATION LOAD BALANCER
# ========================================================
resource "aws_wafv2_web_acl_association" "alb_waf_association" {
  resource_arn = aws_lb.my_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.my_waf.arn
}


/*
For IP sets:

Step 1: Define the IP set
resource "aws_wafv2_ip_set" "my_blocked_ips" {
  name               = "portfolio-blocked-ips"
  description        = "List of known malicious IP addresses"
  scope              = "REGIONAL" # Must match your WAF scope!
  ip_address_version = "IPV4"

  # Add individual IPs with /32 or full ranges with /24, etc.
  addresses = [
    "203.0.113.50/32",
    "198.51.100.0/24"
  ]
}

Step 2: Add the rule to your WAF ACL

# RULE 3: Block requests from the IP Set
  rule {
    name     = "BlockIPSetRule"
    priority = 3

    action {
      block {} # Drop the traffic cleanly
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.my_blocked_ips.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockIPSetMetric"
      sampled_requests_enabled   = true
    }
  }

*/