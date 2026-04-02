# Contributing to HyperFleet Infrastructure

## Development Setup

This repository is primarily infrastructure-as-code and does not require traditional build/compile steps. However, you'll need the appropriate tools to work with Terraform, Helm, and Kubernetes.

```bash
# 1. Clone the repository
git clone https://github.com/openshift-hyperfleet/hyperfleet-infra.git
cd hyperfleet-infra

# 2. Install prerequisites (see Prerequisites section in README.md)
# - Helm + helm-git plugin
# - kubectl
# - Terraform >= 1.5 (for GCP deployments)
# - Google Cloud SDK (for GCP deployments)

# 3. Verify prerequisites are installed
make check-helm
make check-kubectl
make check-terraform  # Only for GCP deployments

# 4. For GCP deployments: Setup Terraform config files
cp terraform/envs/gke/dev.tfvars.example terraform/envs/gke/dev.tfvars
cp terraform/envs/gke/dev.tfbackend.example terraform/envs/gke/dev.tfbackend
# Edit both files: set developer_name and prefix to your username

# 5. For GCP deployments: Authenticate with GCP
gcloud auth application-default login
gcloud config set project hcm-hyperfleet
```

**First-time setup notes:**

- For RabbitMQ-based deployments (non-GCP), Terraform setup is not required
- The `NAMESPACE` variable controls which Kubernetes namespace resources are deployed to (default: `hyperfleet`)
- Use different namespaces for multiple parallel deployments on the same cluster
- The repository uses helm-git plugin to pull charts from other repositories - ensure it's installed

## Repository Structure

```
hyperfleet-infra/
├── Makefile                    # Main entry point - run 'make help' for all targets
├── manifests/
│   └── rabbitmq.yaml           # RabbitMQ development manifest (for BROKER_TYPE=rabbitmq)
├── scripts/
│   └── tf-helm-values.sh       # Generates Helm values from Terraform outputs or env vars
├── helm/                       # Helm charts for HyperFleet components
│   ├── api/                    # HyperFleet API chart
│   ├── sentinel*/              # Sentinel examples
│   ├── adapter*/               # Adapter examples
│   └── maestro/                # Maestro server + agent charts
├── terraform/
│   ├── README.md               # Detailed Terraform documentation
│   ├── main.tf                 # Root module (GKE cluster, Pub/Sub, firewall)
│   ├── bootstrap/              # One-time GCP setup scripts
│   ├── shared/                 # Shared VPC infrastructure (deploy once per project)
│   ├── modules/
│   │   ├── cluster/gke/        # GKE cluster module
│   │   └── pubsub/             # Google Pub/Sub module
│   └── envs/gke/               # Per-environment tfvars and tfbackend files
├── generated-values-from-terraform/  # Auto-generated Helm values (gitignored)
├── README.md                   # Getting started guide
├── CONTRIBUTING.md             # This file
├── CLAUDE.md                   # Instructions for agents
└── CHANGELOG.md                # Version changes to this repo
```

## Testing

This repository focuses on infrastructure provisioning and deployment. Testing is done through validation and dry-run modes.

### Terraform Validation

```bash
# Validate Terraform configuration
cd terraform
terraform init -backend-config=envs/gke/dev.tfbackend
terraform validate
terraform plan -var-file=envs/gke/dev.tfvars
```

### Helm Chart Validation

```bash
# Dry-run Helm installations to validate charts
make install-all DRY_RUN=true

# Check individual components
make install-api DRY_RUN=true
make install-sentinels DRY_RUN=true
make install-adapters DRY_RUN=true
```

### Linting

```bash
# Terraform format check
cd terraform
terraform fmt -check -recursive

# Auto-fix formatting
terraform fmt -recursive
```

## Common Development Tasks

### Working with Terraform

```bash
# Initialize Terraform
cd terraform
terraform init -backend-config=envs/gke/dev.tfbackend

# Plan infrastructure changes
terraform plan -var-file=envs/gke/dev.tfvars

# Apply infrastructure changes
terraform apply -var-file=envs/gke/dev.tfvars

# Destroy infrastructure
terraform destroy -var-file=envs/gke/dev.tfvars
```

### Working with Helm Charts

```bash
# Install all HyperFleet components (GCP with Pub/Sub)
make install-all

# Install all HyperFleet components (RabbitMQ)
make install-all-rabbitmq

# Install individual components
make install-api
make install-sentinels
make install-adapters
make install-maestro

# Uninstall all components
make uninstall-all

# Check deployment status
make status
```

### Generating Helm Values

```bash
# Generate Helm values from Terraform (for Google Pub/Sub)
make tf-helm-values

# Generate Helm values for RabbitMQ
make tf-helm-values BROKER_TYPE=rabbitmq

# Clean generated files
make clean-generated
```

### Using Custom Images

```bash
# Use custom registry
make install-all REGISTRY=quay.io/myuser

# Use specific image tags
make install-all API_IMAGE_TAG=v0.2.0 SENTINEL_IMAGE_TAG=v0.2.0 ADAPTER_IMAGE_TAG=v0.2.0

# Override individual component image tags
make install-api API_IMAGE_TAG=dev-abc123
```

### Working with Multiple Environments

```bash
# Deploy to a specific environment
make install-all TF_ENV=staging NAMESPACE=hyperfleet-staging

# Deploy to custom namespace
make install-all NAMESPACE=my-dev-env
```

## Commit Standards

This project follows [HyperFleet commit standards](https://github.com/openshift-hyperfleet/architecture/blob/main/hyperfleet/standards/commit-standard.md).

Commit message format:

```
HYPERFLEET-XXX - <type>: <subject>
```

Examples:

- `HYPERFLEET-761 - docs: add CONTRIBUTING.md`
- `HYPERFLEET-123 - feat: add support for custom Helm chart refs`
- `HYPERFLEET-456 - fix: correct RabbitMQ URL format in generated values`

## Release Process

This repository does not follow traditional semantic versioning for releases. Instead:

- **Terraform modules** are versioned through git tags and referenced in consuming projects
- **Helm charts** are stored in component repositories (`hyperfleet-api`, `hyperfleet-sentinel`, `hyperfleet-adapter`) and pulled via helm-git plugin
- **Infrastructure changes** are deployed directly from `main` branch after review and approval
- **Image tags** default to component versions (e.g., `v0.1.0` from upstream releases)

When making changes:

1. Create a feature branch from `main`
2. Make your changes and test locally
3. Open a pull request with clear description of changes
4. After review and approval, merge to `main`
5. Changes in `main` can be deployed to environments as needed
