#!/bin/bash

# ! "this is not a regular script; it's a template file that expects variables to be injected into it."

set -e
set -x

# update all packages
sudo apt-get update -y
sudo apt-get upgrade -y

# Install Docker and AWS CLI
sudo apt-get install docker.io awscli -y

systemctl enable docker
systemctl start docker

# We have used IAM Role for EC2-ECR Communication

# Using Docker ECR Login Command to log in inside -- since we have provided it with the role
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 897722695334.dkr.ecr.ap-south-1.amazonaws.com

# Creating a dedicated docker network so our apps can run on top of that
sudo docker network create sre-network || true  # if network is already created, leave it. Removing errors

# Pull Service A
sudo docker pull ${service_a_imageurl}

# Pull Service B
sudo docker pull ${service_b_imageurl}

# RUN Service B (no dependencies)
sudo docker run -d -p 9001:9001 --name service-b --network sre-network --restart always ${service_b_imageurl}

# * Health check for service b. Don't proceed until it doesnt starts fully
while true; do
    if ! curl -s --fail http://localhost:9001/hello &> /dev/null; then
        sleep 1
    else
        break
    fi
done

# Run Service A (Pass RDS HOST & SVC-B-URL AS ENV)
# When two Docker containers are running on the same machine (our EC2 instance), they can communicate with each other directly using localhost 
sudo docker run -d -p 9000:9000 --name service-a --network sre-network --restart always -e DB_HOST=${db_host} -e SERVICE_B_URL=http://service-b:9001/hello ${service_a_imageurl}

# * Also Add Prometheus and grafana to out EC2 Instance

# Running grafana container
docker run -d -p 3000:3000 --name grafana --network sre-network --restart always grafana/grafana


# We need to save  prom configuration file on host machine, because -v expects a file path
# Using tee to take in file input, and send it to /etc/prometheus.yml -- EOF says start reading the content of file 
tee /etc/prometheus.yml &> /dev/null <<EOF
${prometheus_config}
EOF

# Running prometheus container # -v expects path, so providing it path where file is present
docker run -d -p 9090:9090 --name prometheus --network sre-network --restart always \
    -v /etc/prometheus.yml:/etc/prometheus/prometheus.yml \
    prom/prometheus