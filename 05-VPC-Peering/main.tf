# ========================================================
# 1. DATA SOURCES: FETCH DEFAULT NETWORKING (REQUESTER)
# --------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

# We dynamically fetch the Default VPC's Main Route Table so we can add the peering route to it
data "aws_route_table" "default_main" {
  vpc_id = data.aws_vpc.default.id
  filter {
    name   = "association.main"
    values = ["true"]
  }
}

# ========================================================
# 2. NEW CUSTOM VPC & SUBNET (ACCEPTER)
# --------------------------------------------------------
resource "aws_vpc" "peer_vpc" {
  cidr_block           = "10.1.0.0/16" # Completely different range to prevent overlapping!
  enable_dns_hostnames = true

  tags = {
    Name = "portfolio-peer-vpc"
  }
}

resource "aws_subnet" "peer_subnet" {
  vpc_id            = aws_vpc.peer_vpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "portfolio-peer-subnet"
  }
}

resource "aws_route_table" "peer_route_table" {
  vpc_id = aws_vpc.peer_vpc.id

  tags = {
    Name = "portfolio-peer-rt"
  }
}

resource "aws_route_table_association" "peer_subnet_assoc" {
  subnet_id      = aws_subnet.peer_subnet.id
  route_table_id = aws_route_table.peer_route_table.id
}

# ========================================================
# 3. VPC PEERING CONNECTION (THE HANDSHAKE)
# --------------------------------------------------------
resource "aws_vpc_peering_connection" "default_to_peer" {
  vpc_id        = data.aws_vpc.default.id # The Requester
  peer_vpc_id   = aws_vpc.peer_vpc.id     # The Accepter
  auto_accept   = true                    # Works seamlessly because both are in your same AWS account/region

  tags = {
    Name = "Default-to-Peer-Connection"
  }
}

# ========================================================
# 4. ROUTE TABLE UPDATES (THE TWO-WAY STREET)
# --------------------------------------------------------

# Outbound Route: Tells Default VPC how to reach the Custom Peer VPC
resource "aws_route" "default_to_peer_outbound" {
  route_table_id            = data.aws_route_table.default_main.id
  destination_cidr_block    = aws_vpc.peer_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.default_to_peer.id
}

# Return Route: Tells Custom Peer VPC how to reply back to the Default VPC
resource "aws_route" "peer_to_default_return" {
  route_table_id            = aws_route_table.peer_route_table.id
  destination_cidr_block    = data.aws_vpc.default.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.default_to_peer.id
}