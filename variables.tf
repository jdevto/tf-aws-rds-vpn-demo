variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "vpn-rds-demo"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["ap-southeast-2a", "ap-southeast-2b"]
}

variable "one_nat_gateway_per_az" {
  description = "Should be true if you want one NAT Gateway per availability zone. Otherwise, one NAT Gateway will be used for all AZs."
  type        = bool
  default     = true
}

# RDS Configuration
variable "mysql_version" {
  description = "MySQL version for RDS"
  type        = string
  default     = "8.0.43"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "demodb"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "admin"
}

# Office EC2 Configuration
variable "office_instance_type" {
  description = "Office EC2 instance type"
  type        = string
  default     = "t3.micro"
}
