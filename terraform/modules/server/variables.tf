variable "server_name" {
  description = "Name of ec2 instance"
}

variable "security_groups" {
  description = "List of security groups to be applied"
  type        = list(any)
}

variable "user_data" {
  description = "Commands to run on server startup"
}