#!/bin/bash

# Update system
dnf update -y

# Install bind-utils for DNS resolution
dnf install -y bind-utils

# Install MySQL client (MariaDB client is compatible with MySQL)
dnf install -y mariadb105

# Create connection test script
cat > /home/ec2-user/test_rds_connection.sh << 'EOF'
#!/bin/bash

echo "Testing RDS connection..."
echo "RDS Endpoint: ${rds_endpoint}"
echo "Database: ${db_name}"
echo "Username: ${db_username}"
echo ""
echo "To test connection, run:"
echo "mysql -h ${rds_endpoint} -u ${db_username} -p ${db_name}"
echo ""
echo "Note: You'll need to get the password from Terraform outputs or AWS Secrets Manager"
EOF

chmod +x /home/ec2-user/test_rds_connection.sh
chown ec2-user:ec2-user /home/ec2-user/test_rds_connection.sh

# Create a simple connectivity test
cat > /home/ec2-user/test_connectivity.sh << 'EOF'
#!/bin/bash

echo "Testing network connectivity to RDS..."
echo "Pinging RDS endpoint: ${rds_endpoint}"

# Extract hostname from RDS endpoint
RDS_HOST=$(echo "${rds_endpoint}" | cut -d: -f1)
echo "RDS Host: $RDS_HOST"

# Test if we can resolve the hostname
if nslookup $RDS_HOST > /dev/null 2>&1; then
    echo "✓ DNS resolution successful"
else
    echo "✗ DNS resolution failed"
fi

# Test if we can reach the MySQL port
if timeout 5 bash -c "</dev/tcp/$RDS_HOST/3306" 2>/dev/null; then
    echo "✓ Port 3306 is reachable"
else
    echo "✗ Port 3306 is not reachable"
fi

echo ""
echo "If both tests pass, the VPN tunnel is working correctly!"
EOF

chmod +x /home/ec2-user/test_connectivity.sh
chown ec2-user:ec2-user /home/ec2-user/test_connectivity.sh

echo "Office client setup complete!"
echo "Use AWS Systems Manager Session Manager to connect to this instance"
