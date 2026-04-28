# This script registers the Control Node. It runs once when the EC2 starts. It installs your DevOps tools and turns the EC2 into a GitHub Runner.
#!/bin/bash
# 1. Update and install basic dependencies
sudo apt update -y
sudo apt-get install -y git jq unzip curl software-properties-common

# 2. Install Docker
sudo apt-get install -y docker.io git libicu74 curl
sudo systemctl enable --now docker
sudo usermod -aG docker ubuntu

# 3. Install Ansible
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt-get install -y ansible

# 4. Install Terraform
wget -O- https://hashicorp.com | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install terraform -y

# 5. Download & Setup GitHub Runner
mkdir /home/ubuntu/actions-runner && cd /home/ubuntu/actions-runner
curl -o actions-runner-linux-x64.tar.gz -L https://github.com
tar xzf ./actions-runner-linux-x64.tar.gz
chown -R ubuntu:ubuntu /home/ubuntu/actions-runner

# 6. Register the runner using Dynamic Token Registration passed from Terraform by GitHub
REG_TOKEN=$(curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${gh_token}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://github.com \
  | jq -r .token)
sudo -u ubuntu ./config.sh --url ${repo_url} --token $${REG_TOKEN} --name "AWS-Control-Node" --unattended

# 7. Install and start as a background service
sudo ./svc.sh install
sudo ./svc.sh start
