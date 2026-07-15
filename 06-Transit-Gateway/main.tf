# ========================================================
# 1. AMIs & SSH KEY PAIR GENERATION (AUTOMATED)
# --------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu)
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Generate a secure RSA private key
resource "tls_private_key" "tgw_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Register the public key in AWS
resource "aws_key_pair" "tgw_key_pair" {
  key_name   = "tgw-lab-key"
  public_key = tls_private_key.tgw_key.public_key_openssh
}

# Save the private key locally to your folder so you can SSH
resource "local_file" "private_key_file" {
  content         = tls_private_key.tgw_key.private_key_pem
  filename        = "${path.module}/tgw-key.pem"
  file_permission = "0400" # Must have secure permissions to SSH!
}

# ========================================================
# 2. NETWORKING: DEFAULT VPC (SPOKE A)
# --------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

# Grab a single default subnet
data "aws_subnet" "default_1a" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "ap-south-1a"
}

# Grab the active Main route table for the Default VPC 
# (which the default subnets implicitly use)
data "aws_route_table" "default_rt" {
  vpc_id = data.aws_vpc.default.id

  filter {
    name   = "association.main"
    values = ["true"]
  }
}

# ========================================================
# 3. NETWORKING: CUSTOM VPC (SPOKE B)
# --------------------------------------------------------
resource "aws_vpc" "custom_vpc" {
  cidr_block           = "10.2.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "tgw-custom-vpc" }
}

resource "aws_internet_gateway" "custom_igw" {
  vpc_id = aws_vpc.custom_vpc.id
  tags   = { Name = "tgw-custom-igw" }
}

resource "aws_subnet" "custom_subnet_1a" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.2.1.0/24"
  availability_zone = "ap-south-1a"
  tags              = { Name = "tgw-custom-subnet-1a" }
}

resource "aws_route_table" "custom_rt" {
  vpc_id = aws_vpc.custom_vpc.id
  tags   = { Name = "tgw-custom-rt" }
}

resource "aws_route_table_association" "custom_assoc" {
  subnet_id      = aws_subnet.custom_subnet_1a.id
  route_table_id = aws_route_table.custom_rt.id
}

# Route to give Custom VPC access to public internet (so you can SSH)
resource "aws_route" "custom_to_internet" {
  route_table_id         = aws_route_table.custom_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.custom_igw.id
}

# ========================================================
# 4. SECURITY GROUPS
# --------------------------------------------------------

# Default VPC Instance SG
resource "aws_security_group" "default_ec2_sg" {
  name        = "tgw-default-ec2-sg"
  vpc_id      = data.aws_vpc.default.id
  description = "Allow SSH from anywhere and HTTP from custom VPC"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Open for your SSH testing
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.custom_vpc.cidr_block] # Traffic from Spoke B
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [aws_vpc.custom_vpc.cidr_block] # Ping from Spoke B
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Custom VPC Instance SG
resource "aws_security_group" "custom_ec2_sg" {
  name        = "tgw-custom-ec2-sg"
  vpc_id      = aws_vpc.custom_vpc.id
  description = "Allow SSH from anywhere and HTTP from default VPC"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block] # Traffic from Spoke A
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [data.aws_vpc.default.cidr_block] # Ping from Spoke A
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ========================================================
# 5. EC2 INSTANCES (THE TEST SUBJECTS)
# --------------------------------------------------------

resource "aws_instance" "default_ec2" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.default_1a.id
  vpc_security_group_ids      = [aws_security_group.default_ec2_sg.id]
  key_name                    = aws_key_pair.tgw_key_pair.key_name
  associate_public_ip_address = true
  user_data                   = file("${path.module}/userdata.sh")

  tags = { Name = "TGW-Default-Instance" }
}

resource "aws_instance" "custom_ec2" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.custom_subnet_1a.id
  vpc_security_group_ids      = [aws_security_group.custom_ec2_sg.id]
  key_name                    = aws_key_pair.tgw_key_pair.key_name
  associate_public_ip_address = true
  user_data                   = file("${path.module}/userdata.sh")

  tags = { Name = "TGW-Custom-Instance" }
}

# ========================================================
# 6. TRANSIT GATEWAY & ATTACHMENTS
# --------------------------------------------------------
resource "aws_ec2_transit_gateway" "tgw" {
  description                     = "Simplistic TGW Lab Router"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"

  tags = { Name = "portfolio-tgw" }
}

# Spoke A Attachment (Default VPC)
resource "aws_ec2_transit_gateway_vpc_attachment" "default_attach" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = data.aws_vpc.default.id
  subnet_ids         = [data.aws_subnet.default_1a.id]

  tags = { Name = "Default-VPC-Attachment" }
}

# Spoke B Attachment (Custom VPC)
resource "aws_ec2_transit_gateway_vpc_attachment" "custom_attach" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.custom_vpc.id
  subnet_ids         = [aws_subnet.custom_subnet_1a.id]

  tags = { Name = "Custom-VPC-Attachment" }
}

# ========================================================
# 7. INTER-VPC ROUTING OVER TGW
# --------------------------------------------------------

# Route Default RT -> Custom VPC CIDR via TGW
resource "aws_route" "default_to_tgw" {
  route_table_id         = data.aws_route_table.default_rt.id
  destination_cidr_block = aws_vpc.custom_vpc.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}

# Route Custom RT -> Default VPC CIDR via TGW
resource "aws_route" "custom_to_tgw" {
  route_table_id         = aws_route_table.custom_rt.id
  destination_cidr_block = data.aws_vpc.default.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}