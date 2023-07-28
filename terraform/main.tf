# Reference security group module
module "devops_sg" {
  source = "./modules/sgs"
}

# Fetch predefined eksctl_role
data "aws_iam_role" "eksctl_role" {
  name = "eksctl_role"
}

# Create Jenkins server
module "jenkins_server" {
  source          = "./modules/server"
  security_groups = [module.devops_sg.id]
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
  sudo yum install git -y

  sudo wget https://dlcdn.apache.org/maven/maven-3/3.9.3/binaries/apache-maven-3.9.3-bin.tar.gz -P /opt
  sudo tar -xvzf /opt/apache-maven-3.9.3-bin.tar.gz -C /opt/ && sudo mv /opt/apache-maven-3.9.3 /opt/maven

  sudo echo -e "M2_HOME=/opt/maven" >> /root/.bash_profile
  sudo echo -e "M2=/opt/maven/bin" >> /root/.bash_profile
  sudo echo -e "JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto.x86_64\n" >> /root/.bash_profile
  sudo echo 'PATH=$PATH:$HOME/bin:$JAVA_HOME:$M2_HOME:$M2' >> /root/.bash_profile
  sudo echo -e "export PATH" >> /root/.bash_profile

  sudo systemctl enable jenkins
  sudo systemctl start jenkins

EOF
}

# Create Docker server
module "docker_server" {
  source          = "./modules/server"
  security_groups = [module.devops_sg.id]
  server_name     = "Docker Server"
  user_data       = <<-EOF
  #!/bin/bash
  set -e
  sudo yum update -y
  sudo yum install docker -y
  sudo useradd dockeradmin
  sudo echo 'dockeradmin:password' | sudo chpasswd
  sudo usermod -aG docker dockeradmin

  sudo useradd ansadmin
  sudo echo 'ansadmin:password' | sudo chpasswd
  sudo echo 'ansadmin ALL=(ALL) NOPASSWD:ALL' | sudo EDITOR='tee -a' visudo
  sudo sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
  sudo service sshd reload
EOF
}

# Create Kubernetes server
module "kubernetes_server" {
  source          = "./modules/server"
  security_groups = [module.devops_sg.id]
  server_name     = "Kubernetes Server"
  iam_role        = data.aws_iam_role.eksctl_role.name
  user_data       = <<-EOF
  #!/bin/bash
  set -e

  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install

  curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.27.1/2023-04-19/bin/linux/amd64/kubectl
  chmod +x kubectl && mv kubectl /usr/local/bin

  ARCH=amd64
  PLATFORM=$(uname -s)_$ARCH
  curl -sLO "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
  tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
  sudo mv /tmp/eksctl /usr/local/bin

  sudo useradd ansadmin
  sudo echo 'ansadmin:password' | sudo chpasswd
  sudo echo 'root:password' | sudo chpasswd
  sudo echo 'ansadmin ALL=(ALL) NOPASSWD:ALL' | sudo EDITOR='tee -a' visudo
  sudo sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
  sudo service sshd reload
EOF

}

# Create Ansible Server
module "ansible_server" {
  source          = "./modules/server"
  security_groups = [module.devops_sg.id]
  server_name     = "Ansible Server"
  depends_on      = [module.docker_server, module.kubernetes_server]
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

  sudo yum install docker -y
  sudo usermod -aG docker ansadmin
  sudo service docker start

  sudo echo -e "[ansible_host]\nlocalhost\n\n" >> /etc/ansible/hosts
  sudo echo "StrictHostKeyChecking no" > /home/ansadmin/.ssh/config
  sudo -u ansadmin sshpass -p password ssh-copy-id -i /home/ansadmin/.ssh/id_rsa.pub ansadmin@localhost

  sudo echo -e "[docker_host]\n${module.docker_server.privateip}\n\n" >> /etc/ansible/hosts
  sudo echo "StrictHostKeyChecking no" > /home/ansadmin/.ssh/config
  sudo -u ansadmin sshpass -p password ssh-copy-id -i /home/ansadmin/.ssh/id_rsa.pub ansadmin@${module.docker_server.privateip}

  sudo echo -e "[kubernetes]\n${module.kubernetes_server.privateip}" >> /etc/ansible/hosts
  sudo -u ansadmin sshpass -p password ssh-copy-id -i /home/ansadmin/.ssh/id_rsa.pub ansadmin@${module.kubernetes_server.privateip}
  sudo -u ansadmin sshpass -p password ssh-copy-id -i /home/ansadmin/.ssh/id_rsa.pub root@${module.kubernetes_server.privateip}
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

# Print Docker public ip address
output "kubernetes_ip" {
  value = module.kubernetes_server.publicip
}

# Print Ansible public ip address
output "ansible_ip" {
  value = module.ansible_server.publicip
}
