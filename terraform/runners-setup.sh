# This script registers the Control Node. It runs once when the EC2 starts. It installs your DevOps tools and turns the EC2 into a GitHub Runner.
#!/bin/bash
# Install Tools: Docker, Git, Terraform, Ansible
sudo dnf update -y
sudo dnf install -y docker git libicu
sudo systemctl enable --now docker

# Install Terraform
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://hashicorp.com
sudo yum -y install terraform

# Download & Setup GitHub Runner
mkdir /home/ec2-user/actions-runner && cd /home/ec2-user/actions-runner
curl -o actions-runner-linux-x64.tar.gz -L https://github.com
tar xzf ./actions-runner-linux-x64.tar.gz

# Register the runner using the token passed from Terraform
# Note: In production, you'd use a dynamic token API call here
sudo -u ec2-user ./config.sh --url ${repo_url} --token ${gh_token} --name "AWS-Control-Node" --unattended

# Install and start as a background service
sudo ./svc.sh install
sudo ./svc.sh start
