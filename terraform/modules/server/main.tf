# EC2 Server template
resource "aws_instance" "server" {
  ami           = "ami-04823729c75214919"
  instance_type = "t2.micro"
  key_name      = "Braeden-Laptop"

  vpc_security_group_ids = var.security_groups
  tags = {
    Name = var.server_name
  }
  user_data = var.user_data
}

# Public ip address
output "publicip" {
  value = aws_instance.server.public_ip
}
