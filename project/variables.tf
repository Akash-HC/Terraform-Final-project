variable "subnet_cidr" {
    type = list(string)
    default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}
  
variable "subnet_az" {
    type = list(string)
    default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "instance_type" {
    type = string
    description = "Please specify the Instance type for the EC2 instance"
}

variable "key_name" {
    type = string
    description = "Please specify the AWS key for the EC2 instance"
}

  