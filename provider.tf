provider "aws" {
    alias = "dev_env"
    region = "us-east-1"
}

provider "aws" {
  alias = "prod_env"
  region = "us-east-2"
}

#hashicorp vault configuration
provider "vault" {
    address = "http://3.94.55.154:8200" #present vault server address
    skip_child_token = true 

    auth_login {
      path = "auth/approle/login" #mechanism used to authenticate

      parameters = {
        role_id   = "7acb292c-15a1-00cf-7b56-0927e6280984" #replace with your role_id
        secret_id = "a46792b0-fbd9-dbc1-64a6-89cd4d78dcf4" #replace with your secret_id
      }
    }
  
}