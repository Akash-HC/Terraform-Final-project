#Retrieve the secret from vault
data "vault_kv_secret_v2" "secret" {
  mount = "login-secret"
  name = "key-pair"
}

#data block to fetch the latest ubuntu ami image
data "aws_ami" "server_ami" {
    owners = ["099720109477"] #canonical's aws account ID
    most_recent = true

    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
    }
}

#create vpc
resource "aws_vpc" "my-vpc" {
    cidr_block = "10.0.0.0/16"
    instance_tenancy = "default"
    enable_dns_support = true
    enable_dns_hostnames = true
    assign_generated_ipv6_cidr_block = false
    provider = aws.dev_env
    tags = {
        Name = "project-vpc"
    }
}

#create IGW
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.my-vpc.id
    provider = aws.dev_env
    tags = {
        Name = "project-igw"
    }
}

#create route table for IGW 
resource "aws_route_table" "igw-route-table" {
    vpc_id = aws_vpc.my-vpc.id
    provider = aws.dev_env

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
    tags = {
        Name = "project-igw-route-table"
    }
}

#create a map for subnet cidr with az
locals {
  subnet_az_map = zipmap(var.subnet_cidr, var.subnet_az)
}
 
#create subnets 
resource "aws_subnet" "project-subnet" {
    for_each = local.subnet_az_map

    vpc_id = aws_vpc.my-vpc.id
    cidr_block = each.key
    availability_zone = each.value
    provider = aws.dev_env
    map_public_ip_on_launch = true
    tags = {
        Name = "project-subnet-${each.key}"
    }
}
 
#create subnet route table association
resource "aws_route_table_association" "subnet-route-table-association" {
    for_each = local.subnet_az_map

    subnet_id = aws_subnet.project-subnet[each.key].id
    route_table_id = aws_route_table.igw-route-table.id
    provider = aws.dev_env
}

#create security group with ssh, http and https ports 
resource "aws_security_group" "project-sg" {
    vpc_id = aws_vpc.my-vpc.id
    provider = aws.dev_env 

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    } 

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    } 

    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    } 

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    } 

    tags = {
        Name = "project-sg"
    } 
}

# create 2 ec2 instances in each subnet
resource "aws_instance" "project-instance" {
  count = length(var.subnet_cidr) * 2 # Assuming you want 2 instances per subnet

  subnet_id = aws_subnet.project-subnet[element(keys(local.subnet_az_map), count.index % length(var.subnet_cidr))].id
  ami = data.aws_ami.server_ami.id
  instance_type = var.instance_type
  vpc_security_group_ids = [aws_security_group.project-sg.id]
  key_name = var.key_name
  associate_public_ip_address = true
  provider = aws.dev_env

  tags = {
    Name = "project-instance-${count.index}"
  }

#output the server ip and subnet id locally
  provisioner "local-exec" {
    command = "echo The server IP is ${self.public_ip} >> server_ips.txt && echo The subnet ID is ${aws_subnet.project-subnet[element(keys(local.subnet_az_map), count.index % length(var.subnet_cidr))].id} >> subnet_ids.txt"
  }

# commands to be executed on the remote server
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install nginx -y"
    ]

#connecting to the remote server via ssh using the private key stored in vault
        connection {
        type        = "ssh"
        user        = "ubuntu" # Or the appropriate username for your AMI
        private_key = data.vault_kv_secret_v2.secret.data["private-key"] # Because the private key is stored in Vault
        host        = self.public_ip
      }
    }
}
