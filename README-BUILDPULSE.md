# Karpenter Provider AWS - BuildPulse Fork

BuildPulse's fork of [karpenter-provider-aws](https://github.com/aws/karpenter-provider-aws) with custom modifications for our runner infrastructure.

## Repository Structure

```
pkg/providers/version/version.go  # K8s version compatibility (MinK8sVersion, MaxK8sVersion)
pkg/operator/operator.go          # Main operator initialization
pkg/providers/instance/           # EC2 instance provisioning logic
charts/karpenter/                 # Helm chart (we use local chart in buildpulse.io repo)
.github/workflows/                # CI/CD pipelines
```

## Branches

| Branch | Purpose |
|--------|---------|
| `main` | Synced with upstream, latest changes |
| `v0.0.x` | Release branches with BuildPulse customizations |

## CI/CD Pipeline

### Automatic Checks (on PR and push)

The `buildpulse-ci.yaml` workflow runs:
- **Lint** - golangci-lint
- **Test** - Unit tests against K8s 1.30-1.34
- **Build Verification** - Ensures binary compiles
- **Vulnerability Check** - govulncheck

### Release Process

The `buildpulse-release.yaml` workflow triggers on version tags and:
1. Builds multi-arch Docker image (amd64/arm64)
2. Pushes to ECR with tags: `v0.0.x`, `0.0.x`, `latest`
3. Outputs deployment instructions in GitHub Actions summary

## How to Create a New Release

### 1. Create a new release branch from the previous version

```bash
git checkout v0.0.7
git checkout -b v0.0.8
```

### 2. Make your changes

Common changes include:
- Update `MaxK8sVersion` in `pkg/providers/version/version.go`
- Cherry-pick fixes from upstream
- Add BuildPulse-specific modifications

### 3. Commit and push the branch

```bash
git add .
git commit -m "Release v0.0.8: <summary of changes>"
git push origin v0.0.8
```

### 4. Create and push the tag (triggers release)

```bash
git tag v0.0.8
git push origin v0.0.8 --tags
```

### 5. Deploy to cluster

After the release workflow completes, update the Helm values in `buildpulse.io` repo:

```bash
helm upgrade karpenter config/helm/karpenter-controller/karpenter \
  -n admin \
  --reuse-values \
  --set controller.image.tag=v0.0.8
```

## Version Compatibility

Supported Kubernetes versions are defined in `pkg/providers/version/version.go`:

```go
MinK8sVersion = "1.25"
MaxK8sVersion = "1.34"
```

When upgrading EKS clusters, ensure `MaxK8sVersion` includes the target K8s version.

## ECR Repository

- **Registry**: `796224758921.dkr.ecr.us-east-1.amazonaws.com`
- **Repository**: `buildpulse.io/karpenter`
- **Region**: `us-east-1`

## GitHub Actions OIDC Setup

The release workflow uses the existing `buildpulse-github-actions-role` IAM role via OIDC.

**Role ARN:** `arn:aws:iam::796224758921:role/buildpulse-github-actions-role`

**Terraform location:** `buildpulse.io/terraform/oidc/main.tf`

### Required: Add Karpenter Repo to Trust Policy

The trust policy in `terraform/oidc/main.tf` needs to include the karpenter repo. Update the condition to allow both repos:

```hcl
condition {
  test     = "StringLike"
  values   = [
    "repo:BuildPulseLLC/buildpulse.io:*",
    "repo:BuildPulseLLC/karpenter-provider-aws:*"
  ]
  variable = "token.actions.githubusercontent.com:sub"
}
```

### Required: Add ECR Permissions

The role also needs ECR push permissions. Add to the policy in `terraform/oidc/main.tf`:

```hcl
{
  Effect = "Allow"
  Action = [
    "ecr:GetAuthorizationToken",
    "ecr:BatchCheckLayerAvailability",
    "ecr:GetDownloadUrlForLayer",
    "ecr:BatchGetImage",
    "ecr:PutImage",
    "ecr:InitiateLayerUpload",
    "ecr:UploadLayerPart",
    "ecr:CompleteLayerUpload"
  ]
  Resource = "*"
}
```

## Local Development

### Build locally

```bash
make build
```

### Run tests

```bash
make test
```

### Build Docker image locally

```bash
docker build -t karpenter:local .
```

## Related Repositories

- **buildpulse.io** - Main app repo with Helm charts at `config/helm/karpenter-controller/karpenter/`
- **Upstream** - https://github.com/aws/karpenter-provider-aws

## Syncing with Upstream

To pull in upstream changes:

```bash
git remote add upstream https://github.com/aws/karpenter-provider-aws.git
git fetch upstream
git checkout main
git merge upstream/main
git push origin main
```

Then cherry-pick relevant commits into your release branch as needed.