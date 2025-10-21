# VPN to RDS Demo

Simple Terraform demo showing how to connect to a private RDS database through a VPN tunnel.

## What it does

- Creates a private RDS MySQL database
- Simulates an office network with an EC2 instance
- Connects them via VPN through Transit Gateway
- Office can access RDS database securely

## Usage

1. Deploy:

   ```bash
   terraform init
   terraform apply
   ```

2. Connect to office EC2:

   ```bash
   aws ssm start-session --target <instance-id>
   ```

3. Test database connection:

   ```bash
   mysql -h <rds-endpoint> -u admin -p demodb
   ```

## Cleanup

```bash
terraform destroy
```
