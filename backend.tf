terraform {
  backend "s3" {
    bucket = "terraform-project-final" #replace with your bucket name
    key = "Project/terraform.tfstate" #mention the destination folder to store the state file
    region = "us-east-1" 
  }
}