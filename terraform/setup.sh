#!/bin/bash
# setup.sh

# Update package lists
sudo apt-get update -y

# Install Docker
sudo apt-get install -y docker.io

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add 'ubuntu' user to the 'docker' group to run docker commands without sudo
sudo usermod -aG docker ubuntu

# Install AWS CLI
sudo apt-get install -y awscli