# Kubernetes Cluster Automation

This repository contains Infrastructure as Code (IaC) for deploying a production-ready Kubernetes cluster on a local machine using Talos Linux, with automated CI/CD deployment via GitHub Actions.

## Why Talos Linux?

Talos Linux is a modern, secure, and minimal Linux distribution designed specifically for running Kubernetes. This project leverages Talos for several key advantages:

### General Advantages

-   **Immutable Infrastructure**: The entire OS is immutable, preventing runtime modifications and configuration drift
-   **API-Driven**: All system management is done via a gRPC API, eliminating SSH access and manual configuration
-   **Minimal Attack Surface**: No shell, no package manager, no unnecessary services—only what's needed to run Kubernetes
-   **Declarative Configuration**: System configuration is defined declaratively and applied atomically
-   **Automated Updates**: Seamless in-place upgrades with automatic rollback capabilities
-   **Purpose-Built**: Optimized specifically for Kubernetes workloads with no legacy baggage

### Security Advantages

-   **Zero Trust Architecture**: No SSH access means no remote shell vulnerabilities or credential-based attacks
-   **Secure Boot Support**: TPM 2.0 integration and measured boot capabilities for hardware-backed security
-   **Minimal CVE Exposure**: Drastically reduced attack surface compared to traditional Linux distributions
-   **Ephemeral Root Filesystem**: Root filesystem is read-only and rebuilt on every boot
-   **Built-in Encryption**: Native support for disk encryption and secret management
-   **RBAC by Default**: Fine-grained role-based access control for all API operations
-   **No Privilege Escalation**: Absence of shells and package managers eliminates common privilege escalation vectors
-   **CIS Benchmark Compliance**: Designed to meet Kubernetes CIS benchmark requirements out of the box
-   **Kernel Hardening**: Custom kernel with security-focused configurations and minimal module surface

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       ├── app-deploy.yml             # Pipeline definition for app deployment on k8s
│       ├── k8s-deploy.yml             # Pipeline definition for k8s deployment
│       └── monitoring-deploy.yml      # Pipeline definition for k8s monitoring tool deployment
├── kubernetes/
│   └── petclinic.yaml                 # Sample app to test k8s deployment
├── monitoring/
│   └── skooner.yaml                   # Monitoring Tool k8s definition
├── terraform/
│   ├── main.tf                        # Main Terraform configuration
│   ├── variables.tf                   # Input variables for customization
│   ├── outputs.tf                     # Terraform outputs for Talos and Kubernetes config file
│   └── providers.tf                   # Terraform providers definition
└── README.md                          # This file

```

## Terraform Infrastructure

The Terraform configuration is organized into several logical components that work together to provision and configure the Kubernetes cluster:

### Variables Configuration

The `variables.tf` file defines customizable parameters for the deployment:

-   **cluster_name**: Name identifier for the Kubernetes cluster
-   **iso_path**: Filesystem path to the Talos Linux ISO image
-   **cluster_size**: Number of control plane and worker nodes to deploy

These variables allow flexible cluster sizing and configuration without modifying the core infrastructure code.

### Libvirt Provider - VM Provisioning

The libvirt provider handles the creation of virtual machines and their associated resources:

-   **Virtual Machine Definitions**: Creates VMs for control plane and worker nodes with specified CPU, memory, and network configurations
-   **Disk Management**: Provisions virtual disks for each node from the Talos Linux ISO
-   **Network Configuration**: Sets up networking for node communication and cluster connectivity
-   **Resource Allocation**: Manages compute and storage resources for the cluster nodes

### Talos Provider - Cluster Configuration

The Talos provider manages the Kubernetes-specific configuration and bootstrapping:

-   **Machine Configuration Generation**: Creates Talos machine configurations for control plane and worker nodes with appropriate roles and settings
-   **Configuration Application**: Applies generated configurations to the provisioned VMs via the Talos API
-   **Cluster Bootstrapping**: Initializes the Kubernetes cluster on the control plane nodes, establishing etcd and control plane components
-   **Node Registration**: Joins worker nodes to the cluster automatically

This approach provides a fully declarative infrastructure deployment where the entire cluster lifecycle is managed through Terraform state.

## Prerequisites

Before deploying the cluster, ensure the following tools and resources are available:

1.  [Terraform](https://developer.hashicorp.com/terraform/install)
2.  [libvirt](https://documentation.ubuntu.com/server/how-to/virtualisation/libvirt/)
3.  [Talos Linux ISO](https://github.com/siderolabs/talos/releases)
    Place the ISO in a location accessible to libvirt (e.g., `/var/lib/libvirt/images/talos.iso`)
    
4.  [kubectl CLI](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
    
5.  [talosctl](https://docs.siderolabs.com/talos/v1.12/getting-started/talosctl)
    

## Usage

### Local Deployment

1.  **Clone the repository**
    
    ```bash
    git clone https://github.com/bassamomar/k8s-cluster-automation
    cd k8s-cluster-automation
    ```
    
2.  **Initialize Terraform**
    
    ```bash
    cd terraform
    terraform init
    ```
    
3.  **Deploy the cluster**
    
    ```bash
    terraform plan
    terraform apply -var="cluster_name=k8s" -var="iso_path=<ISO_PATH>"
    ```
    
4.  **Retrieve kubeconfig**
    
    ```bash
    terraform output -raw kubeconfig > .kubeconfig
    export KUBECONFIG=$PWD/.kubeconfig
    ```
    
5.  **Verify cluster**
    
    ```bash
    kubectl get nodes
    kubectl get pods -A
    ```
    

### Destroying the Cluster

To tear down the entire cluster:

```bash
terraform destroy
```

## CI/CD Pipeline

This repository implements automated cluster deployment using GitHub Actions with a self-hosted runner. The pipeline architecture addresses the unique requirements of local infrastructure provisioning.

### Architecture Overview

The CI/CD pipeline uses a **GitHub self-hosted runner** deployed as a Docker container with specific configurations to enable Terraform to provision VMs and communicate with Talos endpoints.

### Runner Configuration

The self-hosted runner container is configured with:

-   **libvirt Socket Mount**: The `/run/libvirt` directory is mounted into the runner container, providing access to the libvirt daemon socket for VM provisioning
-   **Network Host Mode**: The container runs with `--network host`, allowing direct network access to Talos API endpoints without NAT or bridge networking complications
-   **ISO Accessibility**: The Talos Linux ISO is placed in a location accessible to both the runner container and the libvirt storage pool

### Runner Setup

```bash
# Run the GitHub Actions runner container
docker run -d \
  --name github-runner \
  --restart always \
  --network host \
  -v /run/libvirt:/run/libvirt \
  -e REPOSITORY="<owner>/<repo>" \
  -e ACCESS_TOKEN="<your-token>" \
  ghcr.io/kevmo314/docker-gha-runner:main

```

### Pipeline Workflow

The `.github/workflows/k8s-deploy.yml` defines the deployment of kubernetes pipeline.

The `.github/workflows/app-deploy.yml` defines the pipeline to deploy a sample application on the Kubernetes cluster.

The `.github/workflows/monitoring-deploy.yml` defines the pipeline to deploy a monitoring tool on the Kubernetes cluster.

----------

## Kubernetes Monitoring

For monitoring Kubernetes, the tool Skooner is used because it is the easiest way to manage a small Kubernetes cluster.

The tool can be deployed using:

```bash
kubectl apply -f monitoring/skooner.yaml
```

Generate the token to access the dashboard:

```bash
# Create the service account in the current namespace (we assume default)
kubectl create serviceaccount skooner-sa

# Give that service account root on the cluster
kubectl create clusterrolebinding skooner-sa --clusterrole=cluster-admin --serviceaccount=default:skooner-sa

kubectl create token skooner-sa
```

Get the monitoring tool link(s) using:

```bash
WEBAPP_PORT=$(kubectl -n kube-system get svc skooner -o jsonpath='{.spec.ports[0].nodePort}')
WEBAPP_IP="$(kubectl get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}')"
echo "Access the monitoring tool using the below link(s):"
while read -r ip; do
  echo "http://${ip}:${WEBAPP_PORT}"
done <<< "$WEBAPP_IP"
```


