# Essential Information
output "rds_endpoint" {
  description = "RDS MySQL endpoint"
  value       = aws_db_instance.mysql.endpoint
}

output "mysql_connection_command" {
  description = "Command to connect to RDS from Office EC2"
  value       = "mysql -h ${aws_db_instance.mysql.endpoint} -u ${var.db_username} -p ${var.db_name}"
}

output "ssm_connection_command" {
  description = "Command to connect to Office EC2 via SSM"
  value       = "aws ssm start-session --target ${aws_instance.office_client.id} --region ${var.region}"
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${var.project_name}-monitoring-dashboard"
}

output "database_password" {
  description = "Database password (sensitive)"
  value       = random_password.db_password.result
  sensitive   = true
}
