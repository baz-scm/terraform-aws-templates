#!/bin/bash
set -e

# Update system
dnf update -y

# Install nginx and openssl
dnf install -y nginx openssl

# Create self-signed certificate
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/nginx.key \
  -out /etc/nginx/ssl/nginx.crt \
  -subj "/C=US/ST=State/L=City/O=BazSpecReview/CN=test-server"

# Create htpasswd file
echo "${username}:$(openssl passwd -apr1 '${password}')" > /etc/nginx/.htpasswd

# Configure nginx
cat > /etc/nginx/conf.d/test.conf <<'EOF'
server {
    listen 443 ssl;
    server_name _;

    ssl_certificate /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;

    auth_basic "Baz Spec Review Test Server";
    auth_basic_user_file /etc/nginx/.htpasswd;

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
EOF

# Create simple test page
cat > /usr/share/nginx/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Baz Spec Review Test Server</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 600px;
            margin: 50px auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background-color: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
        }
        .success {
            color: #27ae60;
            font-weight: bold;
        }
        .info {
            background-color: #e8f4f8;
            padding: 15px;
            border-left: 4px solid #3498db;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎉 Connection Successful!</h1>
        <p class="success">✓ You've successfully connected to the private test server</p>
        <div class="info">
            <p><strong>What this proves:</strong></p>
            <ul>
                <li>VPC connectivity is working</li>
                <li>Security groups are properly configured</li>
                <li>HTTPS with basic authentication is functional</li>
                <li>Browser can access private resources</li>
            </ul>
        </div>
        <p style="margin-top: 20px; color: #7f8c8d; font-size: 0.9em;">
            Server Time: <span id="time"></span>
        </p>
    </div>
    <script>
        document.getElementById('time').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
EOF

# Start and enable nginx
systemctl start nginx
systemctl enable nginx
