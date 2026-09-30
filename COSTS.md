# Cost Estimate & Cleanup

> Rough on-demand estimates for **us-east-1**, USD. Prices change; treat these
> as ballpark and confirm with the AWS Pricing Calculator
> (<https://calculator.aws>) for your region. This repo creates only
> pay-as-you-go resources — there are no upfront commitments.

## What costs money

| Resource | Default qty | ~ Hourly | ~ Monthly (24/7) | Notes |
|----------|-------------|----------|------------------|-------|
| EC2 t3.medium (control-plane) | 1 | ~$0.0416 | ~$30 | Compute |
| EC2 t3.medium (workers) | 3 | ~$0.125 total | ~$90 | Compute |
| EBS gp3 root (30 GB) | 4 | — | ~$10 total | Persists while stopped |
| NAT Gateway | 1 | ~$0.045 + data | ~$33 + data | Egress for pulls |
| Elastic IP (for NAT) | 1 | $0 while attached | $0 | Charged only if unused |
| VPC / subnets / IGW / SGs / IAM | — | $0 | $0 | Free |
| SSM Session Manager | — | $0 | $0 | No cost for sessions |

**Running 24/7 (defaults):** roughly **$160–$175/month**. The dominant levers
are the four EC2 instances (~$120) and the NAT Gateway (~$33 + data).

## Ways to cut cost

1. **Destroy when done** (biggest lever):
   ```bash
   cd terraform && terraform destroy
   ```
   Stops **all** charges. Recreate in ~8 minutes when you want to study again.

2. **Stop instances between sessions** (keeps cluster state on EBS):
   ```bash
   ./scripts/aws-stop.sh      # pauses EC2 compute billing
   ./scripts/aws-start.sh     # ~2-3 min back to Ready
   ```
   While stopped you pay only EBS (~$10/mo) and the NAT Gateway (~$33/mo) if you
   leave it. To also drop the NAT while paused, run `terraform destroy` instead.

3. **Shrink the footprint** in `terraform/terraform.tfvars`:
   ```hcl
   worker_count         = 2
   worker_instance_type = "t3.small"
   ```
   2× t3.small workers + 1 t3.medium control-plane ≈ half the compute cost.

4. **Drop the NAT Gateway** (`enable_nat_gateway = false`). Note: nodes then
   have no internet egress for image/package pulls, so this only works once VPC
   endpoints (ECR/S3/SSM) are added — planned for a later phase.

## Verifying you have nothing left running

```bash
# Any lab instances still up?
aws ec2 describe-instances --region us-east-1 \
  --filters "Name=tag:Project,Values=k8s-lab" \
            "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]' --output table

# NAT gateways?
aws ec2 describe-nat-gateways --region us-east-1 \
  --filter "Name=state,Values=available" \
  --query 'NatGateways[].NatGatewayId' --output text

# Lingering SSM parameters (created at runtime)?
aws ssm get-parameters-by-path --path /k8s-lab --region us-east-1 \
  --query 'Parameters[].Name' --output text
```

After `terraform destroy`, delete any runtime SSM parameters that remain:

```bash
aws ssm delete-parameter --name /k8s-lab/join-command --region us-east-1 || true
aws ssm delete-parameter --name /k8s-lab/control-plane-ready --region us-east-1 || true
```

## Estimated resource usage (per node)

- t3.medium: 2 vCPU, 4 GiB RAM. Control-plane sits ~1 vCPU / ~1.5 GiB idle.
- 30 GB gp3 root is plenty for the OS, containerd images, and lab workloads.
- Bursting: t3 accrues CPU credits when idle and spends them under load — ideal
  for intermittent lab use.
