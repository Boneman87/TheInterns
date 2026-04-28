# This script registers the Control Node. It runs once when the EC2 starts. It installs your DevOps tools and turns the EC2 into a GitHub Runner.
#!/bin/bash
# Install Tools: Docker, Git, Terraform, Ansible
sudo apt update -y
sudo apt-get install -y docker.io git libicu74 curl
sudo systemctl enable --now docker

# Install Terraform
wget -O- https://hashicorp.com | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install terraform -y

# Download & Setup GitHub Runner
mkdir /home/ubuntu/actions-runner && cd /home/ubuntu/actions-runner
curl -o actions-runner-linux-x64.tar.gz -L https://github.com
tar xzf ./actions-runner-linux-x64.tar.gz
chown -R ubuntu:ubuntu /home/ubuntu/actions-runner

# Register the runner using the token passed from Terraform
# Note: In production, you'd use a dynamic token API call here
sudo -u ubuntu ./config.sh --url ${repo_url} --token ${gh_token} --name "AWS-Control-Node" --unattended
sudo -u ec2-user ./config.sh --url ${repo_url} --token ${gh_token} --name "AWS-Control-Node" --unattended

# Install and start as a background service
sudo ./svc.sh install
sudo ./svc.sh start
