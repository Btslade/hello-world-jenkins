# Create Jenkins server
module "jenkins_server" {
  source          = "./modules/server"
  security_groups = [aws_security_group.devops_sg.id]
  server_name     = "Jenkins Server"
  user_data       = <<-EOF
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

# Print public ip address
output "jenkins_ip" {
  value = module.jenkins_server.publicip
}

# Create security group to use
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

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}
