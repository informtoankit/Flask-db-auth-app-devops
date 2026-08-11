# Flask DB App
 
A simple **user authentication web app** (Register / Login) built with **Flask** and **MySQL** — packaged with a complete **DevOps pipeline**: Docker, Kubernetes (EKS), GitOps (ArgoCD), Terraform (AWS infrastructure), and a CI/CD workflow (GitHub Actions) with SonarQube and Trivy scanning.
 
This README explains **what the app does**, **how the code is organized**, and **how to run/deploy it** — from your laptop all the way to a production AWS + Kubernetes setup.
 
---
 
## Table of Contents
 
- [What This Project Does](#what-this-project-does)
- [Tech Stack](#tech-stack)
- [Prerequisites (Read This First)](#prerequisites-read-this-first)
- [Project Structure](#project-structure)
- [How the App Works](#how-the-app-works)
- [Running Locally (Python)](#running-locally-python)
- [Running with Docker Compose (Recommended for Quick Start)](#running-with-docker-compose-recommended-for-quick-start)
- [Environment Variables](#environment-variables)
- [Deploying to Kubernetes (EKS)](#deploying-to-kubernetes-eks)
- [Provisioning AWS Infrastructure with Terraform](#provisioning-aws-infrastructure-with-terraform)
- [GitOps with ArgoCD](#gitops-with-argocd)
- [CI/CD Pipeline (GitHub Actions)](#cicd-pipeline-github-actions)
- [⚠️ Security Notes (Please Read)](#️-security-notes-please-read)
 
---
 
## What This Project Does
 
It's a minimal Flask website with three pages:
 
| Route | Purpose |
|---|---|
| `/` | Home page with links to Register and Login |
| `/register` | Form to create a new user (name, email, password) — saved into MySQL |
| `/login` | Form to log in with email + password, checked against MySQL |
 
It's intentionally simple on the application side — the real focus of this repo is **how the app is built, containerized, and deployed** using a real-world DevOps toolchain.
 
---
 
## Tech Stack
 
- **Backend:** Python, Flask, Flask-MySQLdb
- **Database:** MySQL 8.0
- **Containerization:** Docker, Docker Compose
- **Orchestration:** Kubernetes (Amazon EKS)
- **GitOps:** ArgoCD
- **Infrastructure as Code:** Terraform (provisions RDS MySQL and the EKS cluster)
- **CI/CD:** GitHub Actions (build, scan, push, deploy)
- **Code Quality / Security Scanning:** SonarQube, Trivy
 
---
 
## Prerequisites (Read This First)
 
This repo automates a lot, but **not everything**. The lists below separate what the code/pipeline handles automatically from what a human has to set up manually — read this before assuming a fresh environment will "just work."
 
Legend: ✅ = handled automatically by this repo · 🔲 = manual, one-time setup required
 
### Running Locally (`python run.py`)
 
- 🔲 MySQL server installed and running, reachable from your machine
- 🔲 **`users` table created manually** — the app does **not** create its own schema. Run the `CREATE TABLE` statement in [Running Locally](#running-locally-python) before registering a user, or you'll get a DB error.
- 🔲 `.env` file created in the project root with valid `MYSQL_*` and `SECRET_KEY` values (not committed — see Security Notes)
- 🔲 System build dependencies installed: `gcc`, `default-libmysqlclient-dev`, `pkg-config`, `python3-dev` (see `commands.txt`) — required to compile `Flask-MySQLdb`
- ✅ Python dependencies — handled by `pip install -r requirements.txt`
 
### Running with Docker Compose
 
- 🔲 Docker + Docker Compose installed
- 🔲 Ports `5000` and `3306` free on the host machine
- 🔲 **`users` table still not created automatically** — first run, `docker exec` into the `mysql-db` container and run the `CREATE TABLE` statement once
- ✅ MySQL container, Flask container, networking between them — handled by `docker-compose.yaml`
 
### Running in Production on EKS
 
These are **sequential** — several steps fail silently or confusingly if the one before it hasn't been done. Rough order:
 
1. 🔲 AWS account with IAM permissions to create EKS clusters, RDS instances, IAM roles, VPCs/subnets
2. 🔲 **VPC and subnets must already exist** — `eks-cluster/variables.tf` and `terraform/terraform.tfvars` hardcode specific VPC/subnet IDs from one AWS account. In a different account, these need to be replaced with real values first.
3. 🔲 Apply `eks-cluster/` Terraform — creates the EKS cluster + node group (nothing else in this repo works without this)
4. 🔲 Apply `terraform/` Terraform — creates the RDS MySQL instance
5. 🔲 Confirm the RDS security group actually allows inbound traffic from the EKS nodes (currently wide open — see Security Notes)
6. 🔲 `kubectl` configured for the new cluster: `aws eks update-kubeconfig --name flask-eks-cluster --region us-east-2`
7. 🔲 **`users` table created inside RDS** — connect to the RDS endpoint and run the `CREATE TABLE` statement once. Nothing automates this yet.
8. 🔲 **NGINX Ingress Controller installed** — `k8s/ingress.yaml` sets `ingressClassName: nginx`, but the controller itself is not part of this repo. Install via Helm before the Ingress will do anything.
9. 🔲 **cert-manager installed** — `k8s/cluster-issuer.yaml` needs cert-manager's CRDs already on the cluster. Also a separate Helm install, also not in this repo.
10. 🔲 **DNS record for `app.lucktales.in`** pointed at the Ingress controller's load balancer (e.g. via Route 53) — not automated
11. 🔲 `flask` namespace created: `kubectl create namespace flask`
12. 🔲 **`k8s/secrets.yaml` applied before `k8s/deployment.yaml`** — the Deployment reads env vars from the `flask-secret` Secret; pods will `CrashLoopBackOff` if the Secret doesn't exist yet
13. 🔲 **Docker image already pushed to Docker Hub** — `deployment.yaml` pulls `lucky352/flask-db-auth-app:latest`, which only exists after CI has run at least once, or after a manual `docker push`
14. 🔲 **If using ArgoCD:** ArgoCD itself installed on the cluster first (see `argocd/setup-argocd.txt`) — `argocd/application.yaml` does nothing until ArgoCD exists to read it
15. 🔲 **GitHub Actions secrets configured** in the repo settings — CI fails without all of: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `SONAR_TOKEN`, `SONAR_HOST_URL`, `DOCKER_USERNAME`, `DOCKER_PASSWORD`
16. 🔲 SonarQube host reachable with a valid token (self-hosted or SonarCloud) — the SonarQube scan step in CI fails otherwise
17. ✅ Once 1–16 are done: pushing to `main` builds, scans, and deploys the app automatically via `.github/workflows/build.yaml`
 
> **Note:** As infra improvements land (init scripts for the DB, ALB instead of NGINX, Sealed Secrets, etc.), several manual steps above will become automated — this checklist should be updated alongside those changes so it doesn't go stale.
 
---
 
## Project Structure
 
```
flask-db-app/
├── app/                      # Flask application package
│   ├── __init__.py           # Creates the Flask app & MySQL connection
│   ├── models.py             # Database queries (insert/validate user)
│   └── routes.py             # URL routes (/, /register, /login)
├── templates/                 # HTML pages rendered by Flask
│   ├── index.html
│   ├── login.html
│   └── register.html
├── run.py                     # Entry point — starts the Flask dev server
├── requirements.txt           # Python dependencies
├── Dockerfile                 # Builds the app into a Docker image
├── docker-compose.yaml        # Runs the app + a local MySQL container together
├── commands.txt                # System packages needed to build the app
│
├── .github/workflows/
│   └── build.yaml             # CI/CD pipeline: build, scan, push, deploy to EKS
│
├── k8s/                        # Kubernetes manifests (used in production/EKS)
│   ├── deployment.yaml        # Runs the Flask app as pods
│   ├── service.yaml           # Internal networking (ClusterIP)
│   ├── ingress.yaml           # Exposes the app to the internet via NGINX + TLS
│   ├── cluster-issuer.yaml    # Let's Encrypt certificate issuer for HTTPS
│   └── secrets.yaml           # DB credentials/secret key (as a Kubernetes Secret)
│
├── argocd/
│   ├── application.yaml       # Tells ArgoCD to sync the k8s/ folder to the cluster
│   └── setup-argocd.txt       # Step-by-step commands to install ArgoCD
│
├── terraform/                  # Provisions the AWS RDS MySQL database
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars
│
├── eks-cluster/                 # Provisions the AWS EKS Kubernetes cluster
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── provider.tf
│
├── sonar-project.properties    # SonarQube project config used by CI
└── .env                        # Local environment variables (see Security Notes below)
```
 
---
 
## How the App Works
 
1. **`app/__init__.py`** creates the Flask app, loads settings from a `.env` file, and connects to MySQL using `Flask-MySQLdb`.
2. **`app/routes.py`** defines the three pages (`/`, `/register`, `/login`) and calls functions in `models.py` to talk to the database.
3. **`app/models.py`** contains two raw SQL functions:
   - `insert_user()` — adds a new row to a `users` table (`name`, `email`, `password`)
   - `validate_user()` — looks up a user by email + password to log them in
4. **`templates/*.html`** are very lightweight HTML forms (no CSS/styling) for register/login/home.
5. **`run.py`** starts the built-in Flask development server on port `5000`.
 
> **Note:** The `users` table itself isn't created automatically by the app — you'll need to create it in your MySQL database before registering a user (see below).
 
---
 
## Running Locally (Python)
 
**Prerequisites:** Python 3.10+, a running MySQL server, `gcc`/MySQL client dev headers (see `commands.txt`).
 
1. Clone the repo and enter it:
   ```bash
   git clone https://github.com/Lokeshacharya352/flask-db-app.git
   cd flask-db-app
   ```
2. Install system dependencies needed to build the MySQL Python driver (Debian/Ubuntu):
   ```bash
   sudo apt-get update && sudo apt-get install -y \
       gcc default-libmysqlclient-dev pkg-config python3-dev
   ```
3. Create a virtual environment and install Python dependencies:
   ```bash
   python3 -m venv venv
   source venv/bin/activate      # Windows: venv\Scripts\activate
   pip install -r requirements.txt
   ```
4. Create a `.env` file in the project root (see [Environment Variables](#environment-variables)).
5. In your MySQL database, create the `users` table:
   ```sql
   CREATE DATABASE IF NOT EXISTS flaskdb;
   USE flaskdb;
   CREATE TABLE users (
       id INT AUTO_INCREMENT PRIMARY KEY,
       name VARCHAR(100),
       email VARCHAR(100) UNIQUE,
       password VARCHAR(255)
   );
   ```
6. Run the app:
   ```bash
   python run.py
   ```
7. Open **http://localhost:5000** in your browser.
 
---
 
## Running with Docker Compose (Recommended for Quick Start)
 
This spins up **both** the Flask app and a MySQL database container together — no local MySQL install needed.
 
```bash
docker-compose up --build
```
 
This will:
- Start a `mysql:8.0` container (`mysql-db`) with database `flaskdb`
- Build the Flask app image from the `Dockerfile` and start it as `flask-app`
- Expose the app on **http://localhost:5000** and MySQL on port `3306`
 
You'll still need to create the `users` table inside the MySQL container the first time (connect with any MySQL client using the credentials in `docker-compose.yaml`, then run the `CREATE TABLE` statement above).
 
To stop everything:
```bash
docker-compose down
```
 
---
 
## Environment Variables
 
The app reads these from a `.env` file (loaded via `python-dotenv`) or from the environment (as done in Docker Compose / Kubernetes):
 
| Variable | Description |
|---|---|
| `MYSQL_HOST` | Hostname/endpoint of the MySQL server |
| `MYSQL_PORT` | MySQL port (default `3306`) |
| `MYSQL_USER` | MySQL username |
| `MYSQL_PASSWORD` | MySQL password |
| `MYSQL_DB` | Database name (e.g. `flaskdb`) |
| `SECRET_KEY` | Flask session secret key |
 
**Example `.env` (fill in your own values):**
```env
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=your_user
MYSQL_PASSWORD=your_password
MYSQL_DB=flaskdb
SECRET_KEY=replace-with-a-long-random-string
```
 
---
 
## Deploying to Kubernetes (EKS)
 
The `k8s/` folder contains everything needed to run this app on a Kubernetes cluster (e.g. Amazon EKS):
 
| File | What it does |
|---|---|
| `deployment.yaml` | Runs 2 replicas of the Flask app container, pulling config/secrets from a Kubernetes `Secret`, with liveness/readiness health checks on `/` |
| `service.yaml` | Exposes the pods internally on port `80` (ClusterIP) |
| `ingress.yaml` | Routes external traffic from `app.lucktales.in` to the service, using NGINX Ingress + TLS |
| `cluster-issuer.yaml` | Configures **cert-manager** to auto-issue free HTTPS certificates from Let's Encrypt |
| `secrets.yaml` | Stores DB credentials and the Flask secret key as a Kubernetes `Secret` (see Security Notes) |
 
To deploy manually (assuming `kubectl` is already configured for your cluster):
```bash
kubectl create namespace flask
kubectl apply -f k8s/ -n flask
kubectl rollout status deployment/flask-app -n flask
```
 
---
 
## Provisioning AWS Infrastructure with Terraform
 
This repo provisions AWS infrastructure in **two separate Terraform stacks**:
 
### 1. `terraform/` — MySQL Database (RDS)
Creates:
- An `aws_db_instance` (MySQL 8.0, `db.t3.micro`)
- A DB subnet group and a security group allowing inbound traffic on port `3306`
 
```bash
cd terraform
terraform init
terraform apply
```
 
### 2. `eks-cluster/` — Kubernetes Cluster (EKS)
Creates:
- An `aws_eks_cluster` plus the IAM roles it needs
- A managed node group (EC2 worker nodes, auto-scaling between 1–3 nodes)
 
```bash
cd eks-cluster
terraform init
terraform apply
```
 
> Both stacks currently have AWS region/VPC/subnet IDs and credentials hardcoded in `.tf`/`.tfvars` files — you'll want to replace these with your own AWS account's values before running `terraform apply` (see Security Notes).
 
---
 
## GitOps with ArgoCD
 
`argocd/application.yaml` defines an ArgoCD **Application** that watches the `k8s/` folder in this GitHub repo and automatically keeps the cluster in sync with it (auto-prune + self-heal enabled) — this is the essence of GitOps: Git is the source of truth for what's running in the cluster.
 
`argocd/setup-argocd.txt` walks through installing ArgoCD itself via Helm, retrieving the initial admin password, and accessing the ArgoCD UI locally via `kubectl port-forward`.
 
---
 
## CI/CD Pipeline (GitHub Actions)
 
Defined in `.github/workflows/build.yaml`, triggered on every push to `main` (or manually). The pipeline:
 
1. Checks out the code and sets up Python
2. Authenticates to AWS and connects to the EKS cluster
3. Runs a **SonarQube** scan for code quality/security issues
4. Builds the Docker image with Buildx
5. Logs into Docker Hub and pushes the image
6. Runs a **Trivy** vulnerability scan on the built image
7. Deploys the app to the `flask` namespace on EKS and waits for the rollout to finish
 
This requires the following GitHub Actions **secrets** to be configured in the repo settings: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `SONAR_TOKEN`, `SONAR_HOST_URL`, `DOCKER_USERNAME`, `DOCKER_PASSWORD`.
 
---
 
## ⚠️ Security Notes (Please Read)
 
A few things in the current repo are fine for a learning/demo project but **should not be used as-is in production**:
 
- **Real-looking credentials are committed to the repo** in `.env`, `k8s/secrets.yaml`, and `terraform/terraform.tfvars` (DB host, username, password, Flask secret key). If these were ever real/active credentials, they should be **rotated immediately**, and going forward these files should be added to `.gitignore` and kept out of version control — use a secrets manager (e.g. AWS Secrets Manager, Kubernetes Sealed Secrets, or GitHub Actions secrets) instead.
- **Passwords are stored and compared in plain text** (`app/models.py` inserts and checks `password` directly with no hashing). In a real app, passwords should be hashed (e.g. with `werkzeug.security` or `bcrypt`) before being stored or compared.
- **The database security group allows inbound MySQL traffic from `0.0.0.0/0`** (`terraform/main.tf`) — this should be restricted to only the IPs/security groups that actually need access (e.g. the EKS node security group).
- **`debug=True`** is enabled in `run.py`, which should be turned off in production since it can expose an interactive debugger and stack traces.
 
None of this blocks the app from working — it's just worth cleaning up before this goes anywhere public-facing.
 
---
 
## License
 
No license file is currently included in this repository. Add one (e.g. MIT) if you intend for others to reuse this code.
 