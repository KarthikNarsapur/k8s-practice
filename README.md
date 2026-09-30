# Kubernetes Learning Platform (kubeadm on AWS EC2)

A reusable, production-style Kubernetes practice environment built with
**kubeadm** on **AWS EC2** — deliberately *not* Minikube/kind and *not* EKS —
so you learn what actually happens underneath Kubernetes: static pods, kubelet,
containerd, etcd, the CNI, and real node-level troubleshooting.

- **1 control-plane + 3 workers** (all configurable), Ubuntu 24.04 LTS
- **containerd** runtime, **kubeadm** bootstrap, **Calico** CNI
- **Kubernetes 1.33** (upgrade lab targets 1.34)
- **Access via AWS SSM Session Manager only** — no public SSH, no public API
- **Progressive hands-on labs** with an automated verifier that gives you a
  hint, never the answer

---

## Architecture

```
                     AWS Region (var.region, default us-east-1)
                     VPC 10.50.0.0/16  (2 AZs)
   Internet ── IGW ──┬── Public subnets ── NAT GW (single, toggleable)
                     │                          │ egress for image/pkg pulls
                     └── Private subnets ───────┘
                          ├── control-plane  (t3.medium)  apiserver/etcd/scheduler/cm
                          ├── worker-1       (t3.medium)  kubelet + containerd
                          ├── worker-2       (t3.medium)
                          └── worker-3       (t3.medium)
                          Calico overlay, pod CIDR 192.168.0.0/16

   Access path:  you ──aws ssm start-session──> control-plane ──kubectl──> cluster
```

Details of the design (module structure, sizing, security model, cost strategy,
phases) are in [`DESIGN.md`](DESIGN.md).

### Repository layout

```
.
├── DESIGN.md                 # full design document
├── README.md                 # this file
├── PROGRESS.md               # your progress tracker
├── COSTS.md                  # detailed cost estimate + cleanup
├── HOWTO.md                  # step-by-step: setup, access, practice, cleanup
├── terraform/                # infrastructure as code
│   ├── main.tf variables.tf outputs.tf providers.tf versions.tf
│   ├── terraform.tfvars.example  backend.tf.example
│   └── modules/{network,iam,compute}/
├── scripts/                  # lab engine + cost control
│   ├── lib.sh
│   ├── lab-start.sh lab-verify.sh lab-reset.sh lab-destroy.sh
│   └── aws-stop.sh aws-start.sh
└── labs/                     # the labs
    ├── 01-cluster-architecture/ ... 13-cronjobs/
    └── t01-crashloopbackoff/
```

---

## Prerequisites

- An AWS account and credentials configured locally (env vars, shared profile,
  or SSO). **No credentials are ever stored in this repo.**
- Terraform >= 1.5, AWS CLI v2.
- The **Session Manager plugin** for the AWS CLI (needed for `aws ssm
  start-session`). Install: <https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html>
- IAM permissions to create VPC/EC2/IAM/SSM resources.

---

## Deploy

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # optional: tweak knobs
terraform init
terraform apply
```

What happens on `apply`:
1. VPC, subnets, IGW, single NAT GW, route tables, least-privilege SGs.
2. IAM instance profile (SSM + scoped SSM-parameter access).
3. EC2 nodes boot, run the bootstrap user-data:
   - control-plane: `kubeadm init`, installs Calico, publishes the join
     command to SSM Parameter Store as a **SecureString**.
   - workers: wait for the readiness marker, fetch the join command, join.

The cluster typically takes **~5–8 minutes** to become fully Ready after
`apply` completes (bootstrap runs asynchronously on the nodes).

Check the useful outputs:

```bash
terraform output
```

---

## Connect

There is **no public SSH and no public API endpoint**. You reach the cluster
through SSM Session Manager.

Open a shell on the control-plane:

```bash
# Use the output helper:
terraform -chdir=terraform output -raw control_plane_instance_id
aws ssm start-session --region us-east-1 --target <control-plane-instance-id>
```

Once in the session:

```bash
sudo -i                       # become root (kubeconfig is at /root/.kube/config)
kubectl get nodes -o wide
kubectl get pods -A
```

Watching the bootstrap:

```bash
sudo tail -f /var/log/k8s-bootstrap.log
```

The lab engine (below) runs `kubectl` for you over SSM, so for most labs you
don't need to open a session manually — but troubleshooting labs will ask you
to, on purpose.

---

## Run labs

The engine runs `kubectl` on the control-plane via SSM automatically. Run from
the repo root:

```bash
./scripts/lab-start.sh 05     # set up lab 05's environment
# ... read labs/05-*/README.md and do the challenge ...
./scripts/lab-verify.sh 05    # check your work (hint on failure, never the answer)
./scripts/lab-reset.sh 05     # wipe and re-create the lab from scratch
./scripts/lab-destroy.sh 05   # remove the lab's cluster state
./scripts/lab-destroy.sh --all
```

Lab ids accept `05`, `5`, or `t01`. The verifier prints, on failure:

```
FAILED: <what failed>
Object: <relevant Kubernetes object>
Hint:   <one conceptual hint>
```

The **solution** lives in each lab's `solution.md` and is never printed
automatically — open it only when truly stuck.

### Region / project overrides

The engine defaults to `us-east-1` / project `k8s-lab`. Override via env:

```bash
export AWS_REGION=eu-west-1
export PROJECT_NAME=k8s-lab
```

(Match whatever you set in `terraform.tfvars`.)

---

## Reset a lab

```bash
./scripts/lab-reset.sh 07
```

Deletes the lab namespace (and any cluster-scoped objects the lab created via
its `teardown.sh`), then re-runs setup for a clean starting state.

---

## Cost control

This is a personal environment; keep it cheap. See [`COSTS.md`](COSTS.md) for
the full breakdown.

### Run only when needed (recommended workflow)

The simplest commands live in the `Makefile`:

```bash
make up        # create everything (~8 min, starts billing)
make status    # see what's running + your lab progress
make pause     # stop EC2 (compute billing pauses; NAT+EBS still ~$43/mo)
make resume    # start stopped EC2 (~2-3 min back to Ready)
make down      # destroy ALL AWS resources -> $0 between sessions  (cheapest)
```

**Which to use?**

| Away for… | Do | Cost while away | Time to resume |
|-----------|-----|-----------------|----------------|
| A few hours (same day) | `make pause` | ~$1.40/day (NAT+EBS) | ~2-3 min |
| Overnight / days | `make down` | **$0** | ~8 min |

`make down` is the cheapest and is safe: **your progress is remembered** because
it lives in [`PROGRESS.md`](PROGRESS.md) in this repo, not in the cluster. The
labs recreate their own in-cluster state on the next `lab-start`.

### Progress is tracked automatically

Every `lab-start`/`lab-verify` updates `PROGRESS.md`:
- `lab-start 05` → marks lab 05 **In Progress**
- `lab-verify 05` (fail) → bumps **Attempts**
- `lab-verify 05` (pass) → marks **Completed** with today's date

So across any number of `make down` / `make up` cycles, you always know what's
done and what's pending (`make status` or open `PROGRESS.md`).

### Shrink the footprint (in terraform.tfvars)

```bash
worker_count         = 2
worker_instance_type = "t3.small"
enable_nat_gateway   = false     # requires VPC endpoints (future phase)
```

The single biggest lever is simply **`make down`** (`terraform destroy`) when
you're done for a while.

---

## Destroy infrastructure

```bash
cd terraform
terraform destroy
```

This removes **all** AWS resources (EC2, NAT, EIP, VPC, IAM, SGs). The SSM
parameters under `/k8s-lab/*` are created at runtime by the nodes; remove them
if any linger:

```bash
aws ssm delete-parameter --name /k8s-lab/join-command --region us-east-1 || true
aws ssm delete-parameter --name /k8s-lab/control-plane-ready --region us-east-1 || true
```

---

## Learning progression

Full 12-level roadmap is in [`DESIGN.md`](DESIGN.md). **Phase 1 (this repo)**
ships Levels 1–2 plus a Level-10 troubleshooting starter:

| Level | Theme | Labs in this phase |
|-------|-------|--------------------|
| 1 | Fundamentals | 01 architecture, 02 kubectl, 03 pods, 04 lifecycle, 05 labels/selectors, 06 namespaces |
| 2 | Workloads | 07 replicasets, 08 deployments, 09 rolling updates, 10 rollbacks, 11 daemonsets, 12 jobs, 13 cronjobs |
| 10 | Troubleshooting | t01 CrashLoopBackOff |

Track your status in [`PROGRESS.md`](PROGRESS.md).

Later phases (Networking, Config, Storage, Scheduling, Security, Scaling,
Observability, full Troubleshooting suite, Cluster admin/upgrade, and a
realistic 3-tier app) are designed for but not yet implemented — the Terraform
is structured so add-ons (EKS, Helm, ArgoCD, Prometheus, Cilium, EBS CSI, IRSA)
slot in as new modules without touching the core.

---

## The learning rule

This environment does **not** hide complexity. Labs deliberately push you to
use `kubectl get/describe/logs/exec/explain/get events` and, for node-level
work, `journalctl`, `systemctl`, `crictl`, `ip`, `ss`, `curl`, `dig`,
`tcpdump`. The goal is real troubleshooting skill, not memorized syntax.
