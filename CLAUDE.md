# Claude Code Guidelines for HyperFleet Infrastructure

## Repository Type

Infrastructure-as-Code repository - no application code. Uses Terraform for GCP provisioning and Helm for Kubernetes deployments.

## Quick Validation Commands

Run these commands in order to verify your changes:

```bash
# 1. Validate Terraform formatting
cd terraform && terraform fmt -check -recursive

# 2. Validate Terraform configuration (requires backend setup)
cd terraform && terraform init -backend-config=envs/gke/dev.tfbackend && terraform validate

# 3. Validate Helm charts with dry-run
make install-all DRY_RUN=true

# 4. Check Makefile targets are valid
make help
```

## Critical File Locations

- `Makefile` - All automation targets. Run `make help` to see available commands
- `terraform/` - GCP infrastructure (GKE, Pub/Sub, VPC)
- `helm/` - Kubernetes deployment charts for HyperFleet components
- `scripts/tf-helm-values.sh` - Generates Helm values from Terraform or environment variables
- `generated-values-from-terraform/` - Auto-generated (gitignored), never edit manually

## Common Development Tasks

### Testing Infrastructure Changes

```bash
# Terraform: dry-run infrastructure changes
cd terraform
terraform init -backend-config=envs/gke/dev.tfbackend
terraform plan -var-file=envs/gke/dev.tfvars

# Helm: dry-run deployments
make install-all DRY_RUN=true
make install-api DRY_RUN=true NAMESPACE=test
```

### Working with Makefile Variables

All Makefile targets accept variable overrides:

```bash
# Override namespace
make install-all NAMESPACE=my-dev

# Override broker type
make install-all BROKER_TYPE=rabbitmq

# Override image registry and tags
make install-api REGISTRY=quay.io/myuser API_IMAGE_TAG=dev-abc123

# Combine multiple overrides
make install-all NAMESPACE=staging REGISTRY=quay.io/myuser API_IMAGE_TAG=v0.2.0
```

**Key Variables:**
- `NAMESPACE` (default: `hyperfleet`) - Kubernetes namespace
- `BROKER_TYPE` (default: `googlepubsub`) - Message broker: `googlepubsub` or `rabbitmq`
- `REGISTRY` (default: `quay.io/openshift-hyperfleet`) - Container registry
- `API_IMAGE_TAG`, `SENTINEL_IMAGE_TAG`, `ADAPTER_IMAGE_TAG` (default: `v0.1.1`) - Component versions
- `TF_ENV` (default: `dev`) - Terraform environment name

## Two Deployment Paths

**Path 1: Google Cloud Platform (default)**
- Uses Terraform to provision GKE cluster and Pub/Sub
- Requires `gcloud` CLI and GCP authentication
- Targets: `make install-all`

**Path 2: RabbitMQ (any Kubernetes)**
- No Terraform required, deploys to existing cluster
- Includes dev RabbitMQ manifest
- Targets: `make install-all-rabbitmq`

## Code Conventions

### Terraform

- Use `terraform fmt` before committing
- Module outputs must be documented in `outputs.tf`
- All variables require descriptions in `variables.tf`
- Backend config files (`.tfbackend`) are gitignored - only commit `.example` files

### Helm Charts

- Chart sources live in component repos (`hyperfleet-api`, `hyperfleet-sentinel`, `hyperfleet-adapter`)
- This repo only contains local charts in `helm/` directory
- Use helm-git plugin to reference external charts (see `CHART_ORG` and `*_CHART_REF` variables)

### Makefile

- Each target should have a `## Description` comment for `make help` output
- Use `.PHONY` for all non-file targets
- Prefix prerequisite checks with `check-*`
- Group related targets with comment headers

### Scripts

- All scripts must be executable: `chmod +x scripts/*.sh`
- Use `#!/usr/bin/env bash` shebang
- Fail fast: add `set -euo pipefail` at the top
- Document script arguments with usage function

## What NOT to Do

1. **Do not modify generated files** in `generated-values-from-terraform/` - they are created by `scripts/tf-helm-values.sh`
2. **Do not commit `.tfvars` or `.tfbackend` files** - only commit `.example` versions
3. **Do not commit kubeconfig** or GCP credentials
4. **Do not create Helm releases without checking namespace** - use `make check-namespace` first
5. **Do not assume kubectl context** - always verify with `kubectl config current-context`
6. **Do not hardcode GCP project IDs** - use `GCP_PROJECT_ID` variable
7. **Do not skip dry-run validation** before infrastructure changes
8. **Do not add dependencies to Makefile** without updating `check-*` targets

## Component Relationships

```
Terraform → GKE Cluster + Pub/Sub
    ↓
tf-helm-values.sh → generates broker config
    ↓
Helm Charts → deploy to Kubernetes
    ├── API
    ├── Sentinels (clusters, nodepools)
    ├── Adapters (1, 2, 3)
    └── Maestro (server + agent)
```

## File Modification Guidelines

### When editing Makefile:

- Update `make help` output if adding new targets
- Add prerequisite checks for new external dependencies
- Keep variable defaults at the top of the file
- Test new targets with `DRY_RUN=true` first

### When editing Terraform:

- Run `terraform fmt` before committing
- Update `terraform/README.md` if changing module behavior
- Ensure outputs are documented if used by Helm values script
- Test with `terraform plan` before committing

### When editing Helm charts:

- Validate with `helm template` or `make install-* DRY_RUN=true`
- Update chart version if changing templates
- Document new values in chart's `values.yaml`

## Validation Checklist (run before committing)

```bash
# 1. Format Terraform
cd terraform && terraform fmt -recursive

# 2. Validate Terraform (if you have backend access)
cd terraform && terraform init -backend-config=envs/gke/dev.tfbackend && terraform validate

# 3. Validate Helm deployments
make install-all DRY_RUN=true

# 4. Check Makefile help output
make help

# 5. Verify no sensitive files staged
git status | grep -E '\.tfvars$|\.tfbackend$|kubeconfig' && echo "ERROR: sensitive files staged" || echo "OK"
```

## Architecture Documentation

See [architecture repository](https://github.com/openshift-hyperfleet/architecture) for:
- System design and component interactions
- API specifications and async contracts
- Standards and conventions

## Related Repositories

- [hyperfleet-api](https://github.com/openshift-hyperfleet/hyperfleet-api) - REST API + OpenAPI spec
- [hyperfleet-sentinel](https://github.com/openshift-hyperfleet/hyperfleet-sentinel) - Event monitoring service
- [hyperfleet-adapter](https://github.com/openshift-hyperfleet/hyperfleet-adapter) - Adapter framework
