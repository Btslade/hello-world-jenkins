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

# Create Docker server
module "docker_server" {
  source          = "./modules/server"
  security_groups = [aws_security_group.devops_sg.id]
  server_name     = "Docker Server"
  user_data       = <<-EOF
  #!/bin/bash
  set -e
  sudo yum update -y
  sudo yum install docker -y
  sudo useradd dockeradmin
  sudo echo 'dockeradmin:password' | sudo chpasswd
  sudo usermod -aG docker dockeradmin
  sudo sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config

  sudo useradd ansadmin
  sudo echo 'ansadmin:password' | sudo chpasswd
  sudo echo 'ansadmin ALL=(ALL) NOPASSWD:ALL' | sudo EDITOR='tee -a' visudo
  sudo service sshd reload
EOF
}

# Create Ansible Server
module "ansible_server" {
  source          = "./modules/server"
  security_groups = [aws_security_group.devops_sg.id]
  server_name     = "Ansible Server"
  depends_on = [module.docker_server]
  user_data       = <<-EOF
  #!/bin/bash
  set -e
  sudo useradd -m ansadmin
  sudo echo 'ansadmin:password' | sudo chpasswd
  sudo echo 'ansadmin ALL=(ALL) NOPASSWD:ALL' | sudo EDITOR='tee -a' visudo
  sudo sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
  sudo service sshd reload
  sudo amazon-linux-extras install ansible2
  sudo -u ansadmin mkdir /home/ansadmin/.ssh
  sudo -u ansadmin ssh-keygen -b 2048 -t rsa -f /home/ansadmin/.ssh/id_rsa -q -N ""

  sudo echo -e "[docker_host]\n${module.docker_server.privateip}" >> /etc/ansible/hosts
  sudo echo "StrictHostKeyChecking no" > /home/ansadmin/.ssh/config
  sudo -u ansadmin sshpass -p password ssh-copy-id -i /home/ansadmin/.ssh/id_rsa.pub ansadmin@${module.docker_server.privateip}
EOF
}

# Print Jeknins public ip address
output "jenkins_ip" {
  value = module.jenkins_server.publicip
}

# Print Docker public ip address
output "docker_ip" {
  value = module.docker_server.publicip
}

# Print Ansible public ip address
output "ansible_ip" {
  value = module.ansible_server.publicip
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
