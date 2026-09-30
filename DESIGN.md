# DESIGN — Kubeadm Kubernetes Learning Platform on AWS

## 1. Architecture

A self-managed kubeadm cluster on EC2, deliberately exposing internals (no
managed control plane, no hidden abstractions).

```
                          AWS Region (configurable, e.g. us-east-1)
                          VPC 10.50.0.0/16
   Internet ── IGW ──┬── Public subnets (per AZ) ── NAT GW (single, toggleable)
                     │                                    │
                     └── Private subnets (per AZ) ────────┘ egress only
                          ├── control-plane  t3.medium  apiserver/etcd/scheduler/cm
                          ├── worker-1       t3.medium  kubelet + containerd
                          ├── worker-2       t3.medium
                          └── worker-3       t3.medium
                          Calico overlay (IPIP), pod CIDR 192.168.0.0/16

   Access: AWS SSM Session Manager only (no public SSH, no public API).
```

Key decisions:
- Nodes in **private subnets**, reached only via **SSM Session Manager**.
  Outbound internet (package/image pulls) via a **single NAT Gateway** (cost
  toggle) — or VPC endpoints in a later phase.
- **containerd** runtime (not Docker), **kubeadm** bootstrap, **Calico** CNI
  (production-style; supports NetworkPolicy for later levels).
- **Kubernetes 1.33** base (supported on Ubuntu 24.04; clean 1.33→1.34 upgrade
  lab for Level 11).
- **Ubuntu 24.04 LTS (Noble)**.
- Bootstrapping is automated but transparent: user_data writes/executes the
  bootstrap scripts and (optionally) auto-inits. The join token is passed
  control-plane→workers via **SSM Parameter Store (SecureString)**, never
  hardcoded.

## 2. Terraform module structure

```
terraform/
├── main.tf variables.tf outputs.tf providers.tf versions.tf
├── terraform.tfvars.example  backend.tf.example
└── modules/
    ├── network/   VPC, subnets, IGW, NAT (toggle), routes, SGs
    ├── iam/       SSM instance profile + scoped SSM param access + KMS
    └── compute/   control-plane + workers, user_data, EBS
        └── templates/ common-bootstrap / control-plane / worker (.sh.tftpl)
```

Three small modules keep blast radius small and make it trivial to add future
modules (`modules/eks`, `modules/addons`) without touching the core.

## 3. EC2 sizing

| Role | Count (default) | Type (default) | vCPU/RAM | Disk |
|------|-----------------|----------------|----------|------|
| control-plane | 1 | t3.medium | 2 / 4 GB | 30 GB gp3 |
| worker | 3 | t3.medium | 2 / 4 GB | 30 GB gp3 |

All counts/types are variables (`control_plane_instance_type`,
`worker_instance_type`, `worker_count`). Drop to `worker_count = 2` or
`t3.small` workers for light labs. t3 is burstable (cheap when idle).

## 4. Security model

- **No hardcoded secrets.** Join token via SSM SecureString; everything else
  via Terraform variables.
- **IAM instance profile** per node: `AmazonSSMManagedInstanceCore` + a scoped
  inline policy for the `/k8s-lab/*` SSM parameters + KMS decrypt via the ssm
  service condition.
- **SSM Session Manager only.** No key pair, no port 22 from the internet.
- **Least-privilege SGs**: two cluster SGs (control-plane, worker); all traffic
  allowed strictly *between* the cluster SGs (Calico overlay), NodePort range
  intra-VPC only, egress all (for pulls). No inbound from the internet.
- **IMDSv2 required** on all instances.
- **EBS encrypted** by default.
- Lab secrets use **Kubernetes Secrets** (for teaching), flagged as
  base64-not-encryption.

## 5. Lab progression

12 levels, each lab in the mandated 10-section format, `solution.md` kept
separate so the verifier never prints it.

L1 Fundamentals (01–06) → L2 Workloads (07–13) → L3 Networking (14–20) →
L4 Config (21–26) → L5 Storage (27–32) → L6 Scheduling (33–38) →
L7 Security (39–46) → L8 Scaling (47–50) → L9 Observability (51–56) →
L10 Troubleshooting (broken-env injectors) → L11 Cluster admin (57–65) →
L12 Realistic 3-tier app + failure scenarios.

Progression rule enforced in tooling: labs require `kubectl
get/describe/logs/exec/explain/events`, plus node-level
`journalctl/systemctl/crictl/ip/ss/curl/dig/tcpdump` for troubleshooting.
Verification returns **failure + object + one conceptual hint**, never the fix.

**Phase 1 scope (delivered):** the lab engine + first 14 labs = Level 1 (01–06)
and Level 2 (07–13) plus a Level-10 troubleshooting lab (`t01-crashloopbackoff`)
to establish the broken-environment pattern early.

## 6. Cost-control strategy

- **`terraform destroy`** tears everything down.
- **`single_nat_gateway = true`** default (one NAT, not per-AZ).
  `enable_nat_gateway = false` to run with VPC endpoints only later.
- **Stop, don't destroy:** `scripts/aws-stop.sh` / `aws-start.sh` pause EC2
  billing (EBS persists; cluster survives stop/start).
- **Configurable node count / types** to shrink footprint.
- **No expensive managed services** in Phase 1 (no EKS/LB/RDS). NodePort
  instead of cloud LB.
- See `COSTS.md` for numbers.

## 7. Implementation phases

- **Phase 1 (done):** TF core, bootstrap, cluster auto-forms, lab engine, 14
  labs, docs, validation.
- **Phase 2:** Levels 3–6 (networking, config, storage, scheduling) + Metrics
  Server + local-path storage.
- **Phase 3:** Levels 7–9 (security, scaling, observability) + Prometheus/
  Grafana add-on module.
- **Phase 4:** Levels 10 (full injector library) & 11 (upgrade, etcd backup/
  restore).
- **Phase 5:** Level 12 realistic 3-tier app + failure scenarios.
- **Phase 6 (future, non-blocking):** `modules/eks`, Helm, ArgoCD/GitOps,
  Cilium, service mesh, AWS LB Controller, EBS CSI, IRSA.
