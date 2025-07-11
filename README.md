# Development Environment Setup on Oracle Cloud Free Tier (ARM)

This guide walks you through creating a lightweight, fully open-source development environment on **two ARM Oracle Cloud Free Tier instances**.  
Oracle's Free Tier provides always-free ARM-based instances, ideal for running modern containerized development environments free of charge.

Using **Docker Swarm** on these instances gives you a simple yet powerful container orchestration experience—often described as _"Kubernetes for the budget-conscious"_ or a _"lighter Coolify"_.  
Unlike full Kubernetes, Docker Swarm is easy to set up and maintain for small teams or solo developers.

Our stack uses:

- **Docker Swarm** for orchestration
- **Traefik** as a reverse proxy/load balancer with automatic SSL
- **Portainer** for visual management of the stack
- **Woodpecker CI** for continuous integration and deployment ([Woodpecker CI](https://woodpecker-ci.org/)) (optional)

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
- Registered wildcard DNS under DuckDNS, e.g. `*.your-subdomain.duckdns.org`
- DuckDNS token
- SSH keypair for instance access
- GitHub account for Woodpecker CI integration

> ⚠️ **Note:**  
> While this guide describes a setup with **two ARM instances** for a clustered environment, you can also deploy the entire stack on a **single Oracle Cloud Free Tier instance** with **4 vCPUs and 24 GB RAM**.  
> This is often sufficient for solo developers or small projects, and simplifies networking and management.  
> Simply follow the same instructions, but perform all steps on your single instance.
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

1. **Log in to [Oracle Cloud Platform](https://cloud.oracle.com/) and navigate to Compute > Instances.**
2. **Create two new instances** (e.g., `manager` and `node1`):
    - **Shape:** Select *Ampere A1 Compute* (ARM).
    - **Image:** Choose **Ubuntu Server 22.04** (recommended for compatibility).
    - **CPU/RAM:** 2 OCPUs, 12 GB RAM.
    - **Boot Volume:** 100 GB.
    - **SSH Access:** Upload your SSH public key or paste it into the SSH key field for secure access.

3. **Assign a Static Public IP to the Manager Instance (after instance creation):**
    - After creating your instances, in the Oracle Cloud dashboard, go to **Networking > Virtual Cloud Networks** and select your VCN.
    - Under **Resources**, click **Public IPs** and allocate a new static public IP address.
    - Attach this static IP to the network interface of your `manager` instance by editing its settings.
    - The `node1` instance does not require a public IP; it will communicate internally within the VCN.

4. **Access your instances via SSH:**
    ```sh
    ssh ubuntu@<INSTANCE_PUBLIC_IP>
    ```
    Replace `<INSTANCE_PUBLIC_IP>` with the actual public IP address of your instance.

5. **Update the system for latest security patches and features:**
    ```sh
    sudo apt update && sudo apt upgrade -y
    ```

6. **Configure Cloudflare DNS (1.1.1.1) using systemd-resolved:**
    - Edit the resolved configuration:
      ```sh
      sudo nano /etc/systemd/resolved.conf
      ```
    - Find or add the `DNS=` line and set it to Cloudflare's DNS servers:
      ```
      DNS=1.1.1.1 1.0.0.1
      ```
    - (Optional) To ensure only these DNS servers are used, add or uncomment:
      ```
      DNSStubListener=yes
      ```
    - Save and exit the editor.
    - Restart systemd-resolved to apply changes:
      ```sh
      sudo systemctl restart systemd-resolved
      ```
    - Verify DNS is set correctly:
      ```sh
      systemd-resolve --status | grep 'DNS Servers'
      ```

---
## 🌐 Configuring DuckDNS Dynamic DNS

> 💡 **Tip:**  
> You can use your own DNS provider instead of DuckDNS, as long as it supports **wildcard DNS records** and **DNS-01 challenge** for Let's Encrypt certificate issuance and renewal.  
> Wildcard DNS records are also essential for enabling dynamic app creation: you can deploy new apps or services on any subdomain without manually adding DNS records each time.  
> This allows Traefik (or other reverse proxies) to automatically generate and renew SSL certificates for all your subdomains, and route traffic to new apps as soon as they're deployed.  
> Check your DNS provider's documentation to ensure compatibility with Let's Encrypt DNS challenge and wildcard records.
>
> ⚠️ **Warning:**  
> DuckDNS often has issues with the DNS-01 challenge for Let's Encrypt—certificate requests may fail and you might need to retry several times before it succeeds.  
> For a more reliable experience, consider using a paid DNS provider like **OVH** or **Cloudflare**, both of which fully support wildcard DNS records and the DNS-01 challenge required by Let's Encrypt.


1. Go to [DuckDNS](https://www.duckdns.org/), log in, and create a new subdomain.
2. Assign the **IP of the static IP created** for the `arm1` instance.
3. DuckDNS automatically manages 4th-level subdomains for your chosen 3rd-level subdomain.
4. With DuckDNS, you can use the DNS API for Let's Encrypt certificate management.

> ⚠️ **Warning:**  
> Throughout this guide, make sure to **replace every occurrence of `your-subdomain`** with your actual DuckDNS subdomain.  
> Failing to do so will result in misconfigured URLs, broken SSL certificates, and inaccessible services.

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

# 10. Apply the group membership change to your current session (or simply log out and log back in ... sometimes a reboot is needed).
newgrp docker # or log out and log back in

# 11. Run a test container to verify that Docker is installed correctly.
docker run hello-world
```
---

## 🌟 Initializing Docker Swarm Cluster

Docker Swarm lets you manage a cluster (group) of Docker hosts as a single, highly available system.  
A Swarm consists of two roles:
- **Manager node:** Handles cluster management and orchestration.
- **Worker node:** Runs containers as instructed by the manager.

### Step 1: Initialize the Manager Node

On your main (manager) server, run:

```sh
docker swarm init --advertise-addr <MANAGER_IP>
```

Replace `<MANAGER_IP>` with the **internal LAN IP address** of your manager node (the private IP assigned by Oracle within your Virtual Cloud Network, not the public static IP).  
This command initializes Docker Swarm on your manager and prints a `docker swarm join` command containing a unique token.  
Copy the entire output, especially the `docker swarm join` command, as you will use it on your worker nodes.

Example output:

```sh
Swarm initialized: current node (abcd1234...) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token SWMTKN-1-xxxx <MANAGER_IP>:2377
```

### Step 2: Join Worker Nodes

On every worker node you want to add, use the join command you copied earlier from the manager node:

```sh
docker swarm join --token <WORKER_TOKEN> <MANAGER_IP>:2377
```

- **<WORKER_TOKEN>** is the token portion from your manager's output.
- **<MANAGER_IP>** is the same public IP of your manager node.
- **Port 2377** is the default port for Docker Swarm management.

>Tip:
>If you lose the join command or want to add more nodes later, just run this on the manager to get the current worker token:
>```sh
>docker swarm join-token worker
>```

### Step 3: Verify Your Swarm Cluster

Back on your manager node, list all Swarm nodes:

```sh
docker node ls
```
You should see your manager and all joined workers listed, including their status and roles.
If you see Ready under "STATUS", your nodes are successfully connected.

---

## 📁 Prepare Directory Structure for the Main Stack

Before launching the stack, set up the necessary directories and files for Traefik and the Docker registry.  
Run the following commands on your manager node:

```sh
# 1. Create a working directory for your stack and move into it.
mkdir ~/swarm-oci && cd ~/swarm-oci

# 2. Clone this repository into your working directory.
git clone https://github.com/nihon77/SwarmMicroDevPlatform.git .

# 3. Create a directory for Let's Encrypt certificates and a secure file for Traefik's ACME data.
mkdir letsencrypt && touch letsencrypt/acme.json && chmod 600 letsencrypt/acme.json

# 4. Create directories for the Docker registry's authentication and data storage.
mkdir -p registry/auth registry/data
```

These directories and files are required for Traefik and the registry to function correctly when you deploy the stack.

---

## 🔑 Set Up Registry Authentication and Overlay Network
> 💡 **Tip:**
> You can also use public container registries like [Docker Hub](https://hub.docker.com/), [Quay.io](https://quay.io/), or [GitHub Container Registry](https://github.com/features/packages) to store and distribute your images.  
>  
> Use your private registry only if you want to keep your images confidential or avoid publishing them to public registries.

Before deploying the stack, complete these two steps on your manager node:

1. **Create a password file for the private Docker registry:**

    ```sh
    docker run --entrypoint htpasswd httpd:2 -Bbn admin Pa55Word > registry/auth/htpasswd
    ```

    This command generates a bcrypt-encrypted password file with username `admin` and password `Pa55Word` for registry authentication.

2. **Create the Traefik overlay network for inter-service communication:**

    ```sh
    docker network create --driver=overlay traefik-net
    ```

    This network allows Traefik, Portainer, and other services to communicate securely across the Swarm cluster.

---

## 📝 Configure the `.env` File for Your Installation

Before launching the stack, you must set up the environment variables used by `main-stack.yml` and other configuration files.

1. **Rename the `.env_example` file to `.env`:**

    ```sh
    mv .env_example .env
    ```

2. **Open the `.env` file with your preferred editor:**

    ```sh
    nano .env
    ```

3. **Fill in all required variables** as indicated by the comments in the file.  
   Here’s an overview of the most important variables and how to obtain their values:

    - `DOMAIN_BASE`:  
        The full base domain for your deployment, in the format `<your-subdomain>.duckdns.org` (e.g., `oci-w3style.duckdns.org`).  
        You can find your subdomain in your [DuckDNS account](https://www.duckdns.org/).

    - `DUCKDNS_TOKEN`:  
        Your personal DuckDNS token, required for dynamic IP updates and SSL certificate generation.  
        This is available in your DuckDNS dashboard after logging in.

    - `CERT_EMAIL`:  
        A valid email address, used by Let's Encrypt for SSL certificate management and renewal notifications.

    - `CERT_RESOLVER`:  
        The DNS provider used for certificate resolution (e.g., `duckdns`, `ovh`, `cloudflare`).  
        Set this to match your DNS provider. This value tells Traefik which DNS challenge provider to use for SSL certificates.

4. **Generate the `main-stack.yml` file using the `generate_compose.sh` script:**

    Before running the script, make sure it has execution permissions:

    ```sh
    chmod +x generate_compose.sh
    ```

    Then generate the `main-stack.yml` file with all variables from your `.env` file already substituted:

    ```sh
    ./generate_compose.sh .env main-stack.tpl.yml
    ```

    This command will produce a ready-to-deploy `main-stack.yml` file.

---

## 🧰 Deploy the Main Stack with Docker Compose (`main-stack.yml`)

This step will launch the core services: **Traefik**, **Portainer**, and the **private Docker registry**.

### 1. Deploy the Stack

On your **manager node**, run:

```sh
docker stack deploy -c main-stack.yml main-stack

```

This command deploys the stack defined in `main-stack.yml` under the name `main-stack`.

- **Traefik** will handle reverse proxying and SSL.
- **Portainer** provides a web UI for managing your Docker Swarm.
- **Docker Registry** is your private image repository.

### 2. Accessing Services

- **Registry:** `https://registry.<your-subdomain>.duckdns.org`
- **Portainer:** `https://portainer.<your-subdomain>.duckdns.org`

Replace `<your-subdomain>` with your actual DuckDNS subdomain.


### 3. Authenticate the Docker Registry on All Nodes

> ⚠️ **Attention:**  
> The following step must be performed **on all nodes** in the cluster (both manager and worker).

To push and pull images from your private registry, log in from **every node** (manager and worker):

```sh
docker login registry.<your-subdomain>.duckdns.org
```

Enter the username and password you configured earlier (for example, `admin` / `Pa55Word`).  
This creates a `~/.docker/config.json` file containing your registry credentials.

Next, copy this file to the system-wide Docker config location so that all services (including those running as root) can access the credentials:

```sh
sudo cp ~/.docker/config.json /etc/docker/config.json
```

Repeat these commands on **every node** in the Swarm cluster.

---

Your base stack is now deployed and ready for use.  
You can manage your cluster via Portainer and push/pull images to your private registry securely.

---

## 🚀 Example: Deploying a Test Service (`whoami-stack.yaml`)

To verify your Swarm and Traefik setup, deploy a simple test service using the [traefik/whoami](https://github.com/traefik/whoami) image. This service echoes HTTP request information and is useful for testing routing and SSL.

### 1. Create `whoami-stack.yaml`

Create a file named `whoami-stack.yaml` with the following content.  
**Replace** `<your-subdomain>` with your actual DuckDNS subdomain:

```yaml
version: "3.8"

services:
  whoami:
    image: traefik/whoami
    networks:
      - traefik-net
    deploy:
      replicas: 2
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.whoami.rule=Host(`whoami.<your-subdomain>.duckdns.org`)"
        - "traefik.http.routers.whoami.entrypoints=websecure"
        - "traefik.http.routers.whoami.tls.certresolver=letsencrypt"
        - "traefik.http.services.whoami.loadbalancer.server.port=80"

networks:
  traefik-net:
    external: true
```

### 2. Deploy the Stack

On your manager node, run:

```sh
docker stack deploy -c whoami-stack.yml whoami-stack
```

### 3. Test Access

Visit `https://whoami.<your-subdomain>.duckdns.org` in your browser.  
You should see a page displaying request and container info, confirming Traefik routing and SSL are working.

>After deploying the `whoami` stack, you can use the following Docker commands to verify its status, inspect logs, and manage the stack:
>
>### 📦 List All Running Stacks
>
>To see all currently deployed stacks in your Swarm cluster:
>```sh
>docker stack ls
>```
>### 🔍 Check Service Status
>
>List all running services in the stack:
>```sh
>docker stack services whoami-stack
>```
>
>List all containers (tasks) for the stack:
>```sh
>docker stack ps whoami-stack --no-trunc
>```
>
>### 📄 View Logs
>
>Show logs for the `whoami` service:
>```sh
>docker service logs whoami-stack_whoami
>```
>Or, to follow logs in real time:
>```sh
>docker service logs -f whoami-stack_whoami
>```
>
>### 🛑 Stop and Remove the Stack
>
>To remove (stop and delete) the `whoami` stack and all its services:
>```sh
>docker stack rm whoami-stack
>```
>
>### 🔄 Restart the Stack
>
>To redeploy the stack (useful after changes to the YAML file):
>```sh
>docker stack deploy -c whoami-stack.yaml whoami-stack
>```
>
>#### Forcing Image Re-download
>
>To force Docker to pull the latest image and redeploy:
>```sh
>docker service update --force --with-registry-auth whoami_whoami
>```
>Or, redeploy the stack after removing the service:
>```sh
>docker service rm whoami_whoami
>docker stack deploy -c whoami-stack.yaml whoami
>```

---

## 🛠️ Example: Deploying a Stack via Portainer

### 1. First Login and Password Change

When you access Portainer for the first time at `https://portainer.<your-subdomain>.duckdns.org`, you will be prompted to set an admin password.  
**Choose a strong password and save it securely.**

> **Note:**  
> Portainer may prompt you to restart its container for security reasons before allowing you to set your admin password.

To restart the Portainer service from your manager node, run:

```sh
docker service update --force main-stack_portainer
```

This command forces a restart of the Portainer service within your Swarm stack.


### 2. Deploy via Portainer

> ⚠️ **Warning:**  
> Before deploying, **do not forget to edit the file and replace `<your-subdomain>` with your actual DuckDNS subdomain**.  
> If you leave the example value, your services will not be accessible and SSL configuration will fail.

1. Log in to Portainer at `https://portainer.<your-subdomain>.duckdns.org`.
2. Access Portainer (`https://portainer.<your-subdomain>.duckdns.org`).
2. Go to **Stacks** > **Add stack**.
3. Name your stack (e.g., `whoami-stack`).
4. Paste the contents of `whoami-stack.yaml` into the **Web editor**. 
5. Click **Deploy the stack**.


Portainer will deploy the stack to your Swarm cluster.  
You can now manage, update, or remove the stack directly from the Portainer UI.

> 💡 **Tip:**  
> Portainer also allows you to configure environment variables (env) directly from its web interface when creating or editing a stack. This makes it easy to customize deployment parameters without manually editing YAML files.

---

## 🤖 Continuous Integration Setup with Woodpecker CI (Optional)

Woodpecker CI is an open-source continuous integration system that integrates seamlessly with GitHub and Docker Swarm.  
With Woodpecker, you can automate the build, test, Docker image creation, push to your private registry, and automatic deployment to your Swarm cluster every time you push to a GitHub repository.

### How the CI/CD Flow Works

1. **Push to GitHub:** Every time you push (or open a pull request) on a connected GitHub repository, Woodpecker receives a notification via webhook.
2. **Build and Test:** Woodpecker runs the pipeline defined in the `.woodpecker.yml` file of your repository, which can include build, test, and other steps.
3. **Build Docker Image:** The pipeline can build a new Docker image of your application.
4. **Push to Registry:** The image is pushed to your private registry (e.g., `registry.<your-subdomain>.duckdns.org`).
5. **Deploy to Swarm:** You can add a step to update the service on the Swarm cluster, for example using `docker service update` or `docker stack deploy`.


### Prerequisites

- **Base stack already running** (Traefik, Portainer, Registry)
- **GitHub repository** containing your application code
- **GitHub OAuth App** to allow Woodpecker to authenticate with GitHub
- **`.woodpecker.yml` file** in the repository with your desired pipeline


### 1. Create a GitHub OAuth App

To integrate Woodpecker with GitHub, you need to create a **GitHub OAuth App** for authentication and repository access.

**Steps:**

1. Go to your [GitHub Settings > Developer settings > OAuth Apps](https://github.com/settings/developers).
2. Click **"New OAuth App"**.
3. Fill in the application details:
    - **Application name:** e.g., `woodpecker-ci`
    - **Homepage URL:** `https://ci.<your-subdomain>.duckdns.org`
    - **Authorization callback URL:** `https://ci.<your-subdomain>.duckdns.org/login`
4. Click **"Register application"**.
5. After registration, copy the **Client ID** and **Client Secret**—you will need these for Woodpecker setup.

Use these credentials to configure Woodpecker CI for GitHub integration.


### 1.1. Add Woodpecker CI Environment Variables to the `.env` File

To enable proper integration between Woodpecker CI and GitHub, and to ensure secure communication with agents, add the following variables to your `.env` file (in the same directory as `ci-stack.yml`):

```env
WOODPECKER_ADMIN=<your_github_username>
WOODPECKER_GITHUB_CLIENT=<your_github_client_id>
WOODPECKER_GITHUB_SECRET=<your_github_client_secret>
WOODPECKER_AGENT_SECRET=<your_agent_secret>
```

**Explanation of the variables:**

- `WOODPECKER_ADMIN`:  
    Your GitHub username (one or more separated by comma). This user will have administrator privileges in Woodpecker CI.

- `WOODPECKER_GITHUB_CLIENT`:  
    The Client ID of the GitHub OAuth App you created. Allows Woodpecker to authenticate with GitHub.

- `WOODPECKER_GITHUB_SECRET`:  
    The Client Secret of the GitHub OAuth App. Used for secure communication between Woodpecker and GitHub.

- `WOODPECKER_AGENT_SECRET`:  
    A secret string (choose a long, random password) shared between the Woodpecker server and agents to authenticate internal communication.

### 1.2 Generate the `ci-stack.yml` file using the `generate_compose.sh` script:**

Then generate the `ci-stack.yml` file with all variables from your `.env` file already substituted:

```sh
./generate_compose.sh .env ci-stack.tpl.yml
```

This command will produce a ready-to-deploy `ci-stack.yml` file.

### 2. Deploy the Woodpecker CI Stack

To deploy Woodpecker CI, use the provided `ci-stack.yml` file:

```sh
docker stack deploy -c ci-stack.yml ci-stack
```

This will launch the Woodpecker server and agent services in your Swarm cluster.

### 3. Configure Woodpecker CI
1. Access Woodpecker at `https://ci.<your-subdomain>.duckdns.org`.
2. Log in with your GitHub account.

#### 3.1. Add Registry Secrets to Woodpecker
Before activating your repositories, you need to add secrets for your private Docker registry credentials. These secrets will be used in your CI pipelines to authenticate with your registry.
1. In the Woodpecker UI, click the **gear icon** next to your account avatar to open the **Secrets** section.
2. Add the following secrets:
    - `REGISTRY_USERNAME`: The username for your private Docker registry (e.g., `admin`).
    - `REGISTRY_PASSWORD`: The password you set for your registry (e.g., `Pa55Word`).
    - `REGISTRY_URL`: The password you set for your registry (e.g., `registry.<your-subdomain>.duckdns.org`).
    In the section **Available at the following events** for every secret select **Push** ans **Manual**
3. Save the secrets.  
   You can set these as global secrets or per repository, depending on your security needs.

#### 3.2. Connect Woodpecker to GitHub
1. Activate the repositories you want to use for CI/CD by toggling them in the Woodpecker UI.
2. In the repository options, you can configure whether the pipeline should be **public** or **private**, as well as other security settings.  
    - Go to the repository settings in Woodpecker and choose the pipeline visibility according to your needs.
    - You can also enable or disable features such as network access, filesystem mounts, access to sensitive environment variables, and more.

> ⚠️ **Attention:**  
> Some pipelines may require additional permissions.  
> Make sure to enable, in the **Security** section of the repository options in Woodpecker, the necessary features such as:
> - Network access
> - Filesystem mounts
> - Privileged mode
>  
> These options are essential for pipelines that need to perform Docker builds, access network resources, or manipulate system files.  
> Carefully assess the security risks before enabling these options.

Once activated, Woodpecker will listen for pushes and pull requests on these repositories and trigger pipelines as defined in your `.woodpecker.yml`.

#### 3.3. Configure the `MYAPP_REGISTRY_REPO` Secret in Your Repository

To make your pipeline more flexible and reusable, add a secret named `MYAPP_REGISTRY_REPO` to your repository (click the gear icon next to the repository name in Woodpecker).  
This variable will contain the name of the repository in your private registry where your application image will be published.

1. Go to the **Secrets** section of your repository in Woodpecker (click the gear icon next to the repository name in Woodpecker).
2. Create a new secret named `MYAPP_REGISTRY_REPO`. In the section **Available at the following events** select **Push** ans **Manual**
3. Enter the name of the repository in your private registry where your application image will be published (e.g., `registry.<ypur-subdomain>.duckdns.org/myapp`).

You can then reference this secret in your `.woodpecker.yml` pipeline using the `${MYAPP_REGISTRY_REPO}` syntax to dynamically specify the Docker repository name.  
This approach keeps your private registry URL confidential, even when you commit `.woodpecker.yml` to a public Git repository.

### 4. Add a `.woodpecker.yml` Pipeline to Your Repository

Create a `.woodpecker.yml` file in the root of your repository to define your build and deployment pipeline.  
Example:

```yaml
steps:
    # Build and push the Docker image using Buildx 6
    build-whoami:
        image: woodpeckerci/plugin-docker-buildx:6.0.1
        settings:
            # The 'context' value can be:
            # - A local directory path (e.g., "./" or "../myapp")
            # - A remote Git repository URL (e.g., "https://github.com/your_repo/yourapp.git") if you don't want to fork a repository you don't own, you can build directly from the original repository source.  
            # This is useful if the application is part of a stack and needs to interact with other services, and if you simply want to use the official source without making modifications.
            #   Optionally, you can specify a branch or tag using '#', e.g.:
            #   "https://github.com/your_repo/yourapp.git#main" (main branch)
            #   "https://github.com/your_repo/yourapp.git#v1.2.3" (tag v1.2.3)
            context: "./"
            # Use the Dockerfile in the root of the repository
            dockerfile: Dockerfile
            # Target repository in your private registry
            repo:
                from_secret: WHOAMI_REGISTRY_REPO
            # Tag the image as 'latest' and with the commit SHA
            tags: latest, ${CI_COMMIT_SHA}
            # Push the built image to the registry
            push: true
            # Use secrets for registry Registry address for authentication
            registry: 
                from_secret: REGISTRY_URL
            # Use secrets for registry username and password
            username:
                from_secret: REGISTRY_USERNAME
            password:
                from_secret: REGISTRY_PASSWORD

    # Update the running service in Docker Swarm with the new image
    update-stack:
        image: docker
        environment:
            # Pass registry credentials as environment variables
            REGISTRY_USERNAME:
                from_secret: REGISTRY_USERNAME
            REGISTRY_PASSWORD:
                from_secret: REGISTRY_PASSWORD
            REGISTRY_URL: 
                from_secret: REGISTRY_URL
        volumes:
            # Mount Docker socket to allow Docker CLI commands This needs Trust Volume checked in the repository settings in woodpeacker!
            - /var/run/docker.sock:/var/run/docker.sock
        commands:
            # Log in to the private registry using the provided credentials
            - echo "$REGISTRY_PASSWORD" | docker login $REGISTRY_URL -u "$REGISTRY_USERNAME" --password-stdin
            # Update the Swarm service to use the new image tagged with the commit SHA
            - docker service update --image $REGISTRY_URL/yourapp:${CI_COMMIT_SHA} --with-registry-auth yourapp-stack_yourapp
```
> **Note:**  
> To use the Docker CLI inside your pipeline (e.g., for `docker service update`), you must mount the Docker socket.  
> In Woodpecker, ensure you enable **"Trust Volume"** in the repository settings for this to work securely.


Adjust the pipeline to fit your application's needs.
For more details, see the [Woodpecker CI documentation](https://woodpecker-ci.org/docs/).

---

## 🏆 Bonus: Complete CI/CD Example with Fork of `traefik/whoami` and Woodpecker CI

This section provides a practical, end-to-end example of integrating a real application (a fork of [`traefik/whoami`](https://github.com/traefik/whoami)) with your Docker Swarm environment, Portainer, and Woodpecker CI.

Of course, you can use your own application instead—just ensure your repository includes a `Dockerfile` with the necessary instructions for building and running your app.

### 1. Fork the Repository

- Go to [traefik/whoami](https://github.com/traefik/whoami) and click **Fork** to create a copy in your GitHub account.

### 2. Create the `.woodpecker.yml` File in Your Fork

- In your fork, add a `.woodpecker.yml` file in the root directory with a pipeline similar to the one described above.

    ```yaml
    steps:
        build-whoami:
            image: woodpeckerci/plugin-docker-buildx:6.0.1
            
            settings:
                context: "./"
                dockerfile: Dockerfile
                repo:
                    from_secret: WHOAMI_REGISTRY_REPO
                tags: latest, ${CI_COMMIT_SHA}
                push: true
                registry: 
                    from_secret: REGISTRY_URL
                username:
                    from_secret: REGISTRY_USERNAME
                password:
                    from_secret: REGISTRY_PASSWORD
        
        update-stack:
            image: docker
            environment:
                REGISTRY_USERNAME:
                    from_secret: REGISTRY_USERNAME
                REGISTRY_PASSWORD:
                    from_secret: REGISTRY_PASSWORD
                REGISTRY_URL: 
                    from_secret: REGISTRY_URL
            volumes:
                - /var/run/docker.sock:/var/run/docker.sock
            commands:
                - echo "$REGISTRY_PASSWORD" | docker login $REGISTRY_URL -u "$REGISTRY_USERNAME" --password-stdin
                - docker service update --image $REGISTRY_URL/whoami:${CI_COMMIT_SHA} --with-registry-auth whoami-stack_whoami
    ```

### 3. Deploy the Stack Using Portainer

- Access Portainer (`https://portainer.<your-subdomain>.duckdns.org`).
- Select the environment **Primary**.
- Go to **Stacks > Add stack**. If a stack with the same name already exists, delete it first by selecting the stack and clicking **Remove stack**. 

> **Note:**  
> If you previously created the stack using Portainer, you can remove it directly from the Portainer UI by selecting the stack and clicking **Remove stack**.  
>  
> Alternatively, if the stack was created via the terminal (using `docker stack deploy`), you can remove it with:
> ```sh
> docker stack rm whoami-stack
> ```

- Name the stack (e.g., `whoami-stack`), paste the contents of `whoami-stack.yaml` and add an envirroment section with an example env variable.
    ```yaml
    version: "3.8"

    services:
        whoami:
            image: traefik/whoami
            networks:
                - traefik-net
            deploy:
                replicas: 2
                labels:
                    - "traefik.enable=true"
                    - "traefik.http.routers.whoami.rule=Host(`whoami.<your-subdomain>.duckdns.org`)"
                    - "traefik.http.routers.whoami.entrypoints=websecure"
                    - "traefik.http.routers.whoami.tls.certresolver=letsencrypt"
                    - "traefik.http.services.whoami.loadbalancer.server.port=80"
            environment:
                - EXAMPLE_ENV=${EXAMPLE_ENV}
    
    networks:
        traefik-net:
            external: true
    ```
    > ⚠️ **Warning:**  
    > Throughout this guide, make sure to **replace every occurrence of `your-subdomain`** with your actual DuckDNS subdomain.  
    > Failing to do so will result in misconfigured URLs, broken SSL certificates, and inaccessible services.

- In the **Environment variables** section, create a variable named `EXAMPLE_ENV` with value `DEMO` (just for demonstration).
- Click **Deploy the stack**.
- Verify that the application is working correctly by visiting `https://whoami.<your-subdomain>.duckdns.org` in your browser.

### 4. Log in to Woodpecker CI with Your GitHub Account

- Go to `https://ci.<your-subdomain>.duckdns.org`.
- Log in using your GitHub account.

### 5. Create Global Secrets in Woodpecker

- Click the gear icon (top right) > **Secrets**.
- Add the following global secrets:
    - `REGISTRY_USERNAME`: `admin`
    - `REGISTRY_PASSWORD`: `Pa55Word`
    - `REGISTRY_URL`: `registry.<your-subdomain>.duckdns.org`

### 6. Create and Configure the Repository in Woodpecker

- Activate your forked repository in the Woodpecker dashboard.
- Go to the repository settings (gear icon next to the name).
- In the tab **Project** on the **Trusted** section check **Volumes** and on **Project visibility** select **Internal**.
- In the tab **Secrets**, add the secret `WHOAMI_REGISTRY_REPO` with value `registry.<your-subdomain>.duckdns.org/whoami`.  
    In this section, you should also see the global secrets you created earlier (`REGISTRY_USERNAME`, `REGISTRY_PASSWORD`, `REGISTRY_URL`).
    In the section **Available at the following events** select **Push** ans **Manual**

### 7. Manually Trigger the Pipeline

- From the repository dashboard, click **Run Pipeline** to manually start the pipeline.
- Verify that the jobs run and the image is built and deployed to the stack.

### 8. Edit a File in Your Fork and Verify Pipeline Trigger

- Edit any file in your fork (e.g., README.md).
- Push the change to GitHub.
- Check that Woodpecker automatically triggers the pipeline and updates the service on Swarm.

---






