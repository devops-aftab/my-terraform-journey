# ========================================================
# 1. DATA SOURCE: FETCH LATEST AMAZON LINUX 2023 AMI
# --------------------------------------------------------
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-202*-x86_64"]
  }
}

# ========================================================
# 2. SECURITY GROUP: ALLOW SSH & HTTP TRAFFIC
# --------------------------------------------------------
resource "aws_security_group" "web_sg" {
  name        = "launch-template-sg"
  description = "Allow HTTP and SSH traffic"

  # Inbound HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # In prod, lock this down to your IP!
  }

  # Outbound All Traffic (Needed to download Apache updates)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ========================================================
# 3. THE EC2 LAUNCH TEMPLATE
# --------------------------------------------------------
resource "aws_launch_template" "my_template" {
  name_prefix   = "my-journey-template-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  # Attach the security group we created above
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Inject our external user data script (Base64 encoded required by AWS)
  user_data = filebase64("${path.module}/userdata.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "LT-Instance-Lab02"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}