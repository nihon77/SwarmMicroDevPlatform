# Development Environment Setup on Oracle Cloud Free Tier (ARM)

This guide walks you through creating a lightweight, fully open-source development environment on **two ARM Oracle Cloud Free Tier instances**.  
Oracle's Free Tier provides always-free ARM-based instances, ideal for running modern containerized development environments free of charge.

Using **Docker Swarm** on these instances gives you a simple yet powerful container orchestration experience—often described as _"Kubernetes for the budget-conscious"_ or a _"lighter Coolify"_.  
Unlike full Kubernetes, Docker Swarm is easy to set up and maintain for small teams or solo developers.

Our stack uses:

- **Docker Swarm** for orchestration
- **Traefik** as a reverse proxy/load balancer with automatic SSL
- **Portainer** for visual management of the stack
- **Woodpecker CI** for continuous integration and deployment ([Woodpecker CI](https://woodpecker-ci.org/))

---

## ✨ Advantages of This Solution

- **Lightweight:** All components are optimized to run efficiently on ARM instances with limited resources.
- **Free:** Based on Oracle Cloud Free Tier and free services like DuckDNS.
- **Scalable:** Easily add more nodes to the Docker Swarm cluster as needed.
- **Simple to Configure:** Single `docker-compose.yml` for the stack, Traefik with automatic certificates.
- **Vendor Independent:** No vendor lock-in with expensive proprietary tools.
- **Remote Management:** Portainer provides an intuitive web UI for managing the entire stack.

---

## ⚡ Requirements

- Oracle Cloud account with Free Tier enabled
- **2 ARM instances (Ampere A1):**
  - Ubuntu Server 22.04
  - 2 vCPUs, 12 GB RAM
  - Static public IP addresses
- Registered wildcard DNS under DuckDNS, e.g. `*.oci-w3style.duckdns.org`
- DuckDNS token
- SSH keypair for instance access
- GitHub account for Woodpecker CI integration

---

## 🔹 Components Used

| Component         | Description                                                                  |
|-------------------|------------------------------------------------------------------------------|
| Docker            | Container runtime engine                                                     |
| Docker Swarm      | Cluster orchestration tool                                                   |
| Traefik           | Reverse proxy/load balancer with automatic SSL via DuckDNS and Let's Encrypt |
| DuckDNS           | Free dynamic DNS service with wildcard support                               |
| Portainer         | Web UI to manage Docker Swarm clusters                                       |
| Woodpecker CI     | Lightweight CI/CD server with GitHub integration                             |
| Docker Registry   | Private Docker image registry exposed via Traefik                            |

---

## 🖥️ Creating the ARM Instances on Oracle Cloud Platform

1. Register on [Oracle Cloud Platform](https://cloud.oracle.com/).
2. Create ARM instances (e.g. `arm1`, `arm2`) with:
    - 2 cores
    - 12 GB RAM
    - 100 GB boot disk each
3. Oracle offers 2 public static IP addresses in the Free Tier Plan.
4. Assign a static IP address to the `arm1` instance.

---

## 🌐 Configuring DuckDNS Dynamic DNS

1. Go to [DuckDNS](https://www.duckdns.org/), log in, and create a new subdomain.
2. Assign the IP of the static IP created for the `arm1` instance.
3. DuckDNS automatically manages 4th-level subdomains for your chosen 3rd-level subdomain.
4. With DuckDNS, you can use the DNS API for Let's Encrypt certificate management.

---

## 👷 Installing Docker on Both Instances

```sh
# 1. Remove any old versions of Docker and related components if present.
sudo apt remove docker docker-engine docker.io containerd runc

# 2. Update the package index.
sudo apt update

# 3. Install dependencies required to add Docker's official GPG key and repository.
sudo apt install -y ca-certificates curl gnupg lsb-release

# 4. Create the directory for Docker's GPG key.
sudo mkdir -p /etc/apt/keyrings

# 5. Download Docker's official GPG key and save it in the directory.
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 6. Add Docker's official repository to your system's sources list.
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 7. Update the package index again to include Docker packages from the new repository.
sudo apt update

# 8. Install Docker Engine, CLI, Containerd, Buildx, and the Compose plugin.
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 9. Add your user to the 'docker' group to run Docker commands without sudo.
sudo usermod -aG docker $USER

# 10. Apply the group membership change to your current session (or simply log out and log back in).
newgrp docker # or log out and log back in

# 11. Run a test container to verify that Docker is installed correctly.
docker run hello-world
```sh

## 🌟 Initializing Docker Swarm Cluster

On the manager node:

docker swarm init --advertise-addr <MANAGER_IP>
Note the docker swarm join command output.

On the worker node, run:

docker swarm join --token <TOKEN> <MANAGER_IP>:2377

## 🧰 Launch the Base Stack Docker Compose (main-stack.yml)
Includes Traefik, Portainer, and private Docker registry.
the registry is reachable at registry.<your-subdomain>.duckdns.org
the portainer gui is reachable at registry.<your-subdomain>.duckdns.org

