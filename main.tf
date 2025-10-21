# =============================================================================
# RANDOM SUFFIX FOR UNIQUE NAMES
# =============================================================================

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "random_password" "db_password" {
  length           = 16
  special          = true
  upper            = true
  lower            = true
  numeric          = true
  override_special = "!@#$%&*"
}

# =============================================================================
# RDS VPC - Private subnets only for RDS Multi-AZ
# =============================================================================

# RDS VPC
resource "aws_vpc" "rds" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.tags, {
    Name = "${var.project_name}-rds-vpc"
  })
}

# RDS Private Subnets
resource "aws_subnet" "rds_private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.rds.id
  cidr_block        = cidrsubnet(aws_vpc.rds.cidr_block, 8, count.index + 1)
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.tags, {
    Name = "${var.project_name}-rds-private-subnet-${count.index + 1}"
    Type = "Private"
  })
}

# RDS Private Route Table
resource "aws_route_table" "rds_private" {
  vpc_id = aws_vpc.rds.id

  route {
    cidr_block         = "10.1.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.this.id
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-rds-private-rt"
  })
}

# RDS Private Route Table Associations
resource "aws_route_table_association" "rds_private" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.rds_private[count.index].id
  route_table_id = aws_route_table.rds_private.id
}

# =============================================================================
# OFFICE VPC - Simulates on-premises office
# =============================================================================

# Office VPC
resource "aws_vpc" "office" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.tags, {
    Name = "${var.project_name}-office-vpc"
  })
}

# Office Internet Gateway
resource "aws_internet_gateway" "office" {
  vpc_id = aws_vpc.office.id

  tags = merge(local.tags, {
    Name = "${var.project_name}-office-igw"
  })
}

# Office Public Subnet
resource "aws_subnet" "office_public" {
  vpc_id                  = aws_vpc.office.id
  cidr_block              = cidrsubnet(aws_vpc.office.cidr_block, 8, 1)
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name = "${var.project_name}-office-public-subnet"
    Type = "Public"
  })
}

# Office Private Subnet
resource "aws_subnet" "office_private" {
  vpc_id            = aws_vpc.office.id
  cidr_block        = cidrsubnet(aws_vpc.office.cidr_block, 8, 10)
  availability_zone = var.availability_zones[0]

  tags = merge(local.tags, {
    Name = "${var.project_name}-office-private-subnet"
    Type = "Private"
  })
}

# NAT Gateway EIP
resource "aws_eip" "office_nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.office]

  tags = merge(local.tags, {
    Name = "${var.project_name}-office-nat-eip"
  })
}

# NAT Gateway
resource "aws_nat_gateway" "office" {
  allocation_id = aws_eip.office_nat.id
  subnet_id     = aws_subnet.office_public.id

  tags = merge(local.tags, {
    Name = "${var.project_name}-office-nat-gateway"
  })

  depends_on = [aws_internet_gateway.office]
}

# Office Public Route Table
resource "aws_route_table" "office_public" {
  vpc_id = aws_vpc.office.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.office.id
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-office-public-rt"
  })
}

# Office Private Route Table
resource "aws_route_table" "office_private" {
  vpc_id = aws_vpc.office.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.office.id
  }

  route {
    cidr_block         = "10.0.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.this.id
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-office-private-rt"
  })
}

# Office Route Table Associations
resource "aws_route_table_association" "office_public" {
  subnet_id      = aws_subnet.office_public.id
  route_table_id = aws_route_table.office_public.id
}

resource "aws_route_table_association" "office_private" {
  subnet_id      = aws_subnet.office_private.id
  route_table_id = aws_route_table.office_private.id
}

# =============================================================================
# TRANSIT GATEWAY
# =============================================================================

# Transit Gateway
resource "aws_ec2_transit_gateway" "this" {
  description = "Transit Gateway for RDS VPN Demo"

  tags = merge(local.tags, {
    Name = "${var.project_name}-transit-gateway"
  })
}

# Transit Gateway VPC Attachment (RDS VPC)
resource "aws_ec2_transit_gateway_vpc_attachment" "rds" {
  subnet_ids         = aws_subnet.rds_private[*].id
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = aws_vpc.rds.id

  tags = merge(local.tags, {
    Name = "${var.project_name}-tgw-rds-attachment"
  })
}

# Transit Gateway Route Table
resource "aws_ec2_transit_gateway_route_table" "this" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(local.tags, {
    Name = "${var.project_name}-tgw-route-table"
  })
}

# Transit Gateway Route Table Association (RDS VPC) - Already associated
# resource "aws_ec2_transit_gateway_route_table_association" "rds" {
#   transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.rds.id
#   transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this.id
# }

# Transit Gateway Route Table Propagation (RDS VPC)
resource "aws_ec2_transit_gateway_route_table_propagation" "rds" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.rds.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this.id
}

# =============================================================================
# SITE-TO-SITE VPN
# =============================================================================

# Customer Gateway
resource "aws_customer_gateway" "office" {
  bgp_asn    = 65000
  ip_address = aws_eip.office_nat.public_ip
  type       = "ipsec.1"

  tags = merge(local.tags, {
    Name = "${var.project_name}-customer-gateway"
  })
}

# Site-to-Site VPN Connection
resource "aws_vpn_connection" "office" {
  customer_gateway_id = aws_customer_gateway.office.id
  transit_gateway_id  = aws_ec2_transit_gateway.this.id
  type                = aws_customer_gateway.office.type
  static_routes_only  = true

  tags = merge(local.tags, {
    Name = "${var.project_name}-vpn-connection"
  })
}

# Transit Gateway VPN Attachment
resource "aws_ec2_transit_gateway_vpc_attachment" "office_vpn" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = aws_vpc.office.id
  subnet_ids         = [aws_subnet.office_private.id]

  tags = merge(local.tags, {
    Name = "${var.project_name}-tgw-office-vpn-attachment"
  })
}

# Transit Gateway Route Table Association (Office VPN) - Already associated
# resource "aws_ec2_transit_gateway_route_table_association" "office_vpn" {
#   transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.office_vpn.id
#   transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this.id
# }

# =============================================================================
# COMPREHENSIVE LOGGING AND MONITORING
# =============================================================================

# CloudWatch Log Groups for VPC Flow Logs
resource "aws_cloudwatch_log_group" "rds_vpc_flow_logs" {
  name              = "/aws/vpc/${var.project_name}-rds-vpc-flow-logs"
  retention_in_days = 7

  tags = merge(local.tags, {
    Name = "${var.project_name}-rds-vpc-flow-logs"
  })
}

resource "aws_cloudwatch_log_group" "office_vpc_flow_logs" {
  name              = "/aws/vpc/${var.project_name}-office-vpc-flow-logs"
  retention_in_days = 7

  tags = merge(local.tags, {
    Name = "${var.project_name}-office-vpc-flow-logs"
  })
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "vpc_flow_logs" {
  name = "${var.project_name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.tags, {
    Name = "${var.project_name}-vpc-flow-logs-role"
  })
}

# IAM Policy for VPC Flow Logs
resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${var.project_name}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# VPC Flow Logs for RDS VPC
resource "aws_flow_log" "rds_vpc" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.rds_vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.rds.id

  tags = merge(local.tags, {
    Name = "${var.project_name}-rds-vpc-flow-logs"
  })
}

# VPC Flow Logs for Office VPC
resource "aws_flow_log" "office_vpc" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.office_vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.office.id

  tags = merge(local.tags, {
    Name = "${var.project_name}-office-vpc-flow-logs"
  })
}

# CloudWatch Log Group for RDS
resource "aws_cloudwatch_log_group" "rds_mysql_logs" {
  name              = "/aws/rds/instance/${var.project_name}-mysql/mysql"
  retention_in_days = 7

  tags = merge(local.tags, {
    Name = "${var.project_name}-rds-mysql-logs"
  })
}

# CloudWatch Log Group for EC2 Instance
resource "aws_cloudwatch_log_group" "office_ec2_logs" {
  name              = "/aws/ec2/${var.project_name}-office-client"
  retention_in_days = 7

  tags = merge(local.tags, {
    Name = "${var.project_name}-office-ec2-logs"
  })
}

# CloudWatch Log Group for Transit Gateway
resource "aws_cloudwatch_log_group" "transit_gateway_logs" {
  name              = "/aws/transitgateway/${var.project_name}-transit-gateway"
  retention_in_days = 7

  tags = merge(local.tags, {
    Name = "${var.project_name}-transit-gateway-logs"
  })
}

# CloudWatch Log Group for VPN
resource "aws_cloudwatch_log_group" "vpn_logs" {
  name              = "/aws/vpn/${var.project_name}-vpn-connection"
  retention_in_days = 7

  tags = merge(local.tags, {
    Name = "${var.project_name}-vpn-logs"
  })
}

# Transit Gateway Flow Logs (using VPC Flow Logs instead)
resource "aws_flow_log" "transit_gateway" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.transit_gateway_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.office.id

  tags = merge(local.tags, {
    Name = "${var.project_name}-transit-gateway-flow-logs"
  })
}

# CloudWatch Dashboard for Monitoring
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-monitoring-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", "${var.project_name}-mysql"],
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "${var.project_name}-mysql"],
            ["AWS/RDS", "FreeableMemory", "DBInstanceIdentifier", "${var.project_name}-mysql"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "RDS MySQL Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.office_client.id],
            ["AWS/EC2", "NetworkIn", "InstanceId", aws_instance.office_client.id],
            ["AWS/EC2", "NetworkOut", "InstanceId", aws_instance.office_client.id]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Office EC2 Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/VPN", "TunnelState", "VpnId", aws_vpn_connection.office.id],
            ["AWS/VPN", "TunnelDataIn", "VpnId", aws_vpn_connection.office.id],
            ["AWS/VPN", "TunnelDataOut", "VpnId", aws_vpn_connection.office.id]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "VPN Connection Metrics"
          period  = 300
        }
      }
    ]
  })
}

# Transit Gateway Route Table Propagation (Office VPN)
resource "aws_ec2_transit_gateway_route_table_propagation" "office_vpn" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.office_vpn.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this.id
}

# =============================================================================
# RDS MULTI-AZ CLUSTER
# =============================================================================

# DB Subnet Group
resource "aws_db_subnet_group" "rds" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = aws_subnet.rds_private[*].id

  tags = merge(local.tags, {
    Name = "${var.project_name}-rds-subnet-group"
  })
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-"
  vpc_id      = aws_vpc.rds.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"] # Office VPC CIDR
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-rds-sg"
  })
}

# RDS Instance
resource "aws_db_instance" "mysql" {
  identifier = "${var.project_name}-mysql-${random_string.suffix.result}"

  engine         = "mysql"
  engine_version = var.mysql_version
  instance_class = var.rds_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.rds.name

  multi_az            = true
  publicly_accessible = false
  skip_final_snapshot = true
  deletion_protection = false

  tags = merge(local.tags, {
    Name = "${var.project_name}-mysql"
  })
}

# =============================================================================
# OFFICE CLIENT EC2
# =============================================================================

# IAM Role for SSM
resource "aws_iam_role" "office_ec2" {
  name = "${var.project_name}-office-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.tags, {
    Name = "${var.project_name}-office-ec2-role"
  })
}

# Attach SSM policy
resource "aws_iam_role_policy_attachment" "office_ec2_ssm" {
  role       = aws_iam_role.office_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile
resource "aws_iam_instance_profile" "office_ec2" {
  name = "${var.project_name}-office-ec2-profile"
  role = aws_iam_role.office_ec2.name

  tags = merge(local.tags, {
    Name = "${var.project_name}-office-ec2-profile"
  })
}

# Office EC2 Security Group
resource "aws_security_group" "office_ec2" {
  name_prefix = "${var.project_name}-office-ec2-"
  vpc_id      = aws_vpc.office.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-office-ec2-sg"
  })
}

# Office EC2 Instance
resource "aws_instance" "office_client" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.office_instance_type
  subnet_id     = aws_subnet.office_private.id

  vpc_security_group_ids = [aws_security_group.office_ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.office_ec2.name

  user_data_base64 = base64encode(templatefile("${path.module}/user_data.sh", {
    rds_endpoint = aws_db_instance.mysql.endpoint
    db_name      = var.db_name
    db_username  = var.db_username
  }))

  tags = merge(local.tags, {
    Name = "${var.project_name}-office-client"
  })
}

# Data source for Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
