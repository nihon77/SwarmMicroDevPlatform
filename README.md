# Development Environment Setup on Oracle Cloud Free Tier (ARM)

This document guides you through creating a lightweight, fully open-source development environment on two ARM Oracle Cloud Free Tier instances. Oracle's Free Tier offers always-free ARM-based instances with decent specs (2 vCPUs, 12 GB RAM), making it an excellent choice for small teams, hobbyists, or anyone looking to experiment with cloud infrastructure without cost.

Using Docker Swarm on these instances provides a simplified yet powerful container orchestration experience, often considered "Kubernetes for the budget-conscious" or a "lighter Coolify." Unlike full Kubernetes clusters, Docker Swarm is easier to configure, less resource-intensive, and perfectly suited for smaller environments where simplicity and efficiency matter most.

We use Docker Swarm for orchestration, Traefik as a reverse proxy/load balancer with automatic SSL, Portainer for visual stack management, and Woodpecker CI for continuous integration and deployment (CI/CD) with GitHub authentication.

##✨ Advantages of This Solution

Lightweight: All components are optimized to run efficiently on ARM instances with limited resources.
Free: Based on Oracle Cloud Free Tier and free services like DuckDNS.
Scalable: Easily add more nodes to the Docker Swarm cluster as needed.
Simple to Configure: Single docker-compose.yml for stack, Traefik with automatic certificates.
Vendor Independent: No vendor lock-in with expensive proprietary tools.
Remote Management: Portainer provides an intuitive web UI for managing the entire stack.

##⚡ Requirements

Oracle Cloud account with Free Tier enabled
2 ARM instances (Ampere A1) with:
Ubuntu Server 22.04
2 vCPUs, 12 GB RAM
Static public IP addresses
Registered wildcard DNS under DuckDNS: *.oci-w3style.duckdns.org
DuckDNS token
SSH keypair for instance access
GitHub account for Woodpecker CI integration

##🔹 Components Used

Component	Description
Docker	Container runtime engine
Docker Swarm	Cluster orchestration tool
Traefik	Reverse proxy/load balancer with automatic SSL via DuckDNS and Let's Encrypt
DuckDNS	Free dynamic DNS service with wildcard support
Portainer	Web UI to manage Docker Swarm clusters
Woodpecker CI	Lightweight CI/CD server with GitHub integration
Docker Registry	Private Docker image registry exposed via Traefik

## Create the arm istance on Oracle Cloud Platform
register on ocp, create arm istances (es arm1, arm2) with 2 core , 12gb of ram and a boot disk of 100gb each.
Oracle offer 2 public static ip in the Free Tier Plan. assign a static ip on the arm1 istance


## 🌐 Configuring DuckDNS Dynamic DNS
on duckdns.org login and create a new sub domain, ad assign the ip of the static ip created for the arm1 istance
duckdns.org automatically manage the 4 level subdomain for the 3 level subdomain of your choice. also with duckdns we can use dns api for Let's encrypt certificate management

##👷 Installing Docker on Both Instances

sudo apt remove docker docker-engine docker.io containerd runc
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker $USER
newgrp docker o logout/login

docker run hello-world

##🌟 Initializing Docker Swarm Cluster

On the manager node:

docker swarm init --advertise-addr <MANAGER_IP>
Note the docker swarm join command output.

On the worker node, run:

docker swarm join --token <TOKEN> <MANAGER_IP>:2377

##🧰 Launch the Base Stack Docker Compose (main-stack.yml)
Includes Traefik, Portainer, and private Docker registry.
the registry is reachable at registry.<your-subdomain>.duckdns.org
the portainer gui is reachable at registry.<your-subdomain>.duckdns.org

