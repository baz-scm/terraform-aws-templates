output "test_server_private_ip" {
  description = "Private IP of the test server (accessible only from within VPC)"
  value       = aws_instance.test_server.private_ip
}

output "test_server_url" {
  description = "HTTPS URL of the test server"
  value       = "https://${aws_instance.test_server.private_ip}"
}

output "test_server_credentials" {
  description = "Test server login credentials"
  value = {
    username = "testuser"
    password = "TestPassword123!"
  }
  sensitive = true
}
