# Infrastructure to hold terraform state file
#terraform {
#  backend "s3" {
#    bucket         = "theinterns-terraform-state-001" # Double-check this name!
#    key            = "global/s3/terraform.tfstate"
#    region         = "eu-central-1"
#    dynamodb_table = "terraform-state-locking"
#    encrypt        = true
#  }
#}
# Configure the AWS Provider
provider "aws" {
  region = "eu-central-1" 
}

# 1. Create a VPC and Public Subnet
resource "aws_vpc" "theinterns" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "TheInterns-VPC"
  }
}

# 2. Create the Internet Gateway (Required for internet access)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.theinterns.id
  
  tags = {
    Name = "TheInterns-IGW"
  }
}

# 3. Create the Public Subnet with Name and Auto-IP
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.theinterns.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true # Gives instances a Public IP automatically
  
  tags = {
    Name = "TheInterns-Public-Subnet"
  }
}

# 4. Create a Route Table (The "Map" to the Internet)
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.theinterns.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "TheInterns-Public-RT"
  }
}

# 5. Link the Subnet to the Route Table
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# 6. IAM Role config for SSM (So you can log in without SSH).
# Trust Policy: This defines who can use the role (EC2)
resource "aws_iam_role" "ssm_role" {
  name = "ControlNodeSSMRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

# 7. Access Permisisions Policy: This defines what the role can do. (Minimum permissions for an instance to use Systems and Sessions Manager) 
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 8. IAM Instance Profile: attaches the role to the instance.
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ControlNodeProfile"
  role = aws_iam_role.ssm_role.name
}

# Adding the Control Node Security Group
resource "aws_security_group" "control_node_sg" {
  name        = "control-node-sg"
  vpc_id      = aws_vpc.theinterns.id
  description = "Security group for DevOps Control Node"

  # No Inbound rules needed for SSM!
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "Control-Node-SG" }
}

# 9. The Control Node Instance
resource "aws_instance" "control_node" {
  ami           = data.aws_ami.ubuntu_24_04.id # Fetches Amazon Ubuntu 24.04 LTS AMI from data.tf
  instance_type = "c7i-flex.large"
  subnet_id     = aws_subnet.public.id
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  vpc_security_group_ids = [aws_security_group.control_node_sg.id]

  # Pass the shell script to the instance
  user_data = templatefile("runner-setup.sh", {
    gh_token = var.gh_token,
    repo_url = "https://github.com/Boneman87/TheInterns"
  })

  tags = { Name = "Control-Node-Runner" }
  user_data_replace_on_change = true # this line causes a new Control-node instance to be launch anytine there is a slight change in the runner-setup.sh file
}

