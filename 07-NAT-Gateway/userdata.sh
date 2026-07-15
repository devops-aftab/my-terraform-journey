#!/bin/bash
# Log execution state to check bootstrap progress
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "========================================="
echo "Starting System Update (Requires Internet Access!)"
echo "========================================="
apt-get update -y

echo "Installing Apache2 and Curl..."
apt-get install -y apache2 curl

echo "Enabling & Starting Web Service..."
systemctl start apache2
systemctl enable apache2

# Extract IMDSv2 token for EC2 local metadata
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)

# Build custom landing validation page
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>NAT Gateway Diagnostic Dashboard</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 40px; background-color: #f4f6f9; color: #333; }
        .card { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.08); max-width: 600px; margin: auto; }
        h1 { color: #232f3e; border-bottom: 2px solid #ff9900; padding-bottom: 10px; }
        .badge { background: #2ecc71; color: white; padding: 6px 12px; border-radius: 4px; font-weight: bold; font-size: 0.9em; display: inline-block; }
        .info-block { background: #f8f9fa; border-left: 4px solid #0073bb; padding: 10px 15px; margin: 15px 0; }
    </style>
</head>
<body>
    <div class="card">
        <h1>Lab 07: NAT Gateway Verification</h1>
        <p>Your EC2 instances are properly isolated and routing.</p>
        <div class="info-block">
            <strong>Host Private IP:</strong> $PRIVATE_IP<br>
            <strong>Service Deployment:</strong> Apache Server
        </div>
        <p><strong>Deployment Status:</strong> <span class="badge">ONLINE & ACTIVE</span></p>
        <p><small>Bootstrap Timestamp: $(date)</small></p>
    </div>
</body>
</html>
EOF

echo "System Bootstrap Complete."