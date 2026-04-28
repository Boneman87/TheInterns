# S3 bucket and DynamoDB details for state file. 
terraform {
  backend "s3" {
    bucket         = "theinterns-terraform-state-unique-id"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locking"
    encrypt        = true
  }
}


# Configure the AWS Provider
provider "aws" {
  region = "eu-central-1" 
}

# 1. Create a VPC and Public Subnet
resource "aws_vpc" "theinterns" { cidr_block = "10.0.0.0/16" }

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.theinterns.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# 2. IAM Role config for SSM (So you can log in without SSH).
# Trust Policy: This defines who can use the role (EC2)
resource "aws_iam_role" "ssm_role" {
  name = "ControlNodeSSMRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

# Access Permisisions Policy: This defines what the role can do. (Minimum permissions for an instance to use Systems and Sessions Manager) 
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ControlNodeProfile"
  role = aws_iam_role.ssm_role.name
}

# 3. The Control Node Instance
resource "aws_instance" "control_node" {
  ami           = "ami-0abed25eed793978d" # Amazon Ubuntu 24.04 LTS AMI
  instance_type = "c7i-flex.large"
  subnet_id     = aws_subnet.public.id
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  # Pass the shell script to the instance
  user_data = templatefile("runner-setup.sh", {
    gh_token = var.gh_token,
    repo_url = "https://github.com"
  })

  tags = { Name = "Control-Node-Runner" }
}

