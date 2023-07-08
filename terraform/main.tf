# Create Jenkins Server
resource "aws_instance" "jenkins" {
  ami           = "ami-04823729c75214919"
  instance_type = "t2.micro"
  key_name      = "Braeden-Laptop"

  vpc_security_group_ids = [aws_security_group.devops_sg.id]
  tags = {
    Name = "Jenkins Server"
  }
  user_data = <<-EOF
  #!/bin/bash
  set -e
  sudo yum update -y
  sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
  sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
  sudo yum upgrade -y
  sudo yum install java-11 -y
  sudo yum install jenkins -y
  sudo systemctl enable jenkins
  sudo systemctl start jenkins
EOF
}

output "publicip" {
  value = aws_instance.jenkins.public_ip
}

resource "aws_security_group" "devops_sg" {
  name        = "devops-sg"
  description = "Security group for basic devops"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  # Custom TCP
  ingress {
    from_port   = 8000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks =["0.0.0.0/0"]
  }
}
