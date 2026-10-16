# =============================================================================
# MODULE: network  (console Phase 1)
# =============================================================================
# Builds the private network the server lives in:
#   VPC, one public and one private subnet, internet gateway, NAT gateway,
#   two route tables, two security groups, five interface endpoints and one
#   S3 gateway endpoint.
#
# Traffic paths (same as the console build):
#   AWS services (ssm, logs, kms) : private subnet to interface endpoints
#   S3                            : private subnet to S3 gateway endpoint
#   Ubuntu package mirrors        : private subnet to NAT to internet gateway
# =============================================================================

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  # Both must be on for interface endpoints to use private DNS
  # (so ssm.eu-west-2.amazonaws.com resolves to the endpoint's private IP).
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.name_prefix}-vpc" }
}

# -----------------------------------------------------------------------------
# Subnets
# -----------------------------------------------------------------------------
# Where the server lives. No public IPs are ever assigned here.
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = { Name = "${var.name_prefix}-private-subnet" }
}

# Only holds the NAT gateway. "Public" because its route table points at the
# internet gateway (the name means nothing to AWS).
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = { Name = "${var.name_prefix}-public-subnet" }
}

# -----------------------------------------------------------------------------
# Internet gateway and NAT gateway
# -----------------------------------------------------------------------------
# The VPC's door to the internet. Creating it with vpc_id also attaches it.
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name_prefix}-igw" }
}

# Fixed public IP for the NAT gateway. Unlike the console, it gets tagged
# automatically (default_tags plus this Name tag).
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.name_prefix}-nat-eip" }
}

# Outbound-only internet for the private subnet (Ubuntu updates).
# Must sit in the PUBLIC subnet.
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = { Name = "${var.name_prefix}-nat" }

  # The NAT needs the internet gateway to exist first. There is no direct
  # reference between them, so the order is stated explicitly.
  depends_on = [aws_internet_gateway.this]
}

# -----------------------------------------------------------------------------
# Route tables
# -----------------------------------------------------------------------------
# The local route (10.20.0.0/16) is added by AWS automatically, so only the
# extra routes are written here.

# Public: everything not local goes to the internet gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = { Name = "${var.name_prefix}-public-rt" }
}

# Private: everything not local goes to the NAT gateway (outbound only).
# The S3 gateway endpoint below adds its own S3 prefix list route here.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = { Name = "${var.name_prefix}-private-rt" }
}

# Associations link each subnet to its own route table.
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# -----------------------------------------------------------------------------
# Security groups
# -----------------------------------------------------------------------------
# Rules are written as separate resources (the current AWS provider
# recommendation). A group created this way has NO rules until they are added.

# Instance: no inbound at all. Outbound 443 and 80 only.
resource "aws_security_group" "instance" {
  name        = "${var.name_prefix}-instance-sg"
  description = "CIS server - no inbound, outbound web only"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.name_prefix}-instance-sg" }
}

# HTTPS out: SSM, CloudWatch, KMS, S3 and the snap store.
resource "aws_vpc_security_group_egress_rule" "instance_https" {
  security_group_id = aws_security_group.instance.id
  description       = "HTTPS to AWS services and package sources"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

# HTTP out: Ubuntu apt mirrors (packages are verified with GPG signatures).
resource "aws_vpc_security_group_egress_rule" "instance_http" {
  security_group_id = aws_security_group.instance.id
  description       = "HTTP to Ubuntu apt mirrors"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

# Endpoints: accept HTTPS only from resources wearing the instance group.
resource "aws_security_group" "endpoints" {
  name        = "${var.name_prefix}-endpoints-sg"
  description = "VPC interface endpoints - 443 from CIS instance only"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.name_prefix}-endpoints-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_from_instance" {
  security_group_id            = aws_security_group.endpoints.id
  description                  = "HTTPS from the CIS instance security group"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.instance.id # source = SG, not a CIDR
}

# -----------------------------------------------------------------------------
# VPC endpoints
# -----------------------------------------------------------------------------
# for_each creates ONE endpoint per item in the set, so five endpoints are
# written once instead of five times. each.value is the current service name.
resource "aws_vpc_endpoint" "interface" {
  for_each = toset(["ssm", "ssmmessages", "ec2messages", "logs", "kms"])

  # Subnet and security group are written once for all five endpoints, so the
  # two console mistakes (wrong security group, missing subnet) cannot happen.
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${var.name_prefix}-vpce-${each.value}" }
}

# S3 gateway endpoint: a free route for S3 in the private route table.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = { Name = "${var.name_prefix}-vpce-s3" }
}
