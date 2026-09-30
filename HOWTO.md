# HOWTO — Kubernetes Lab (setup, access, practice)

A practical, step-by-step guide to running and practicing in this environment.
For architecture and design see [`README.md`](README.md) and [`DESIGN.md`](DESIGN.md);
for cost detail see [`COSTS.md`](COSTS.md).

---

## How do I set up the environment (first time)?

**1. Install the one missing prerequisite — the SSM Session Manager plugin**
(needed to open interactive shells on nodes; the lab engine itself does not
require it):

```bash
# Debian/Ubuntu / WSL:
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o /tmp/smp.deb
sudo dpkg -i /tmp/smp.deb
session-manager-plugin --version   # verify
```

(Terraform >= 1.5 and AWS CLI v2 are already installed. AWS credentials must be
configured — env vars, shared profile, or SSO. Terraform state is stored
remotely in S3.)

**2. Bring the cluster up:**

```bash
cd /mnt/c/Users/KarthikN/Downloads/k8s-practice
make up
```

This runs `terraform apply`. It creates the VPC, NAT, 1 control-plane + 3
workers; the nodes self-bootstrap kubeadm + Calico. **Wait ~5–8 minutes** for
the cluster to finish forming.

**3. Confirm it's ready:**

```bash
make status
```

When nodes appear under `== Nodes ==` as `Ready`, you're good. If it says
"API not reachable yet," wait another minute or two (bootstrap still running).

---

## How do I access the cluster?

For most labs you don't need to open a shell — the lab engine runs `kubectl` on
the control-plane for you over SSM.

**A. Let the engine do it (default):** just use `./scripts/lab-*.sh`.

**B. Open an interactive shell on the control-plane** (needed for troubleshooting
labs — `journalctl`, `systemctl`, `crictl`, `ss`, `tcpdump`):

```bash
CP=$(terraform -chdir=terraform output -raw control_plane_instance_id)
aws ssm start-session --region us-east-1 --target "$CP"

# Once connected:
sudo -i                       # become root; kubeconfig at /root/.kube/config
kubectl get nodes -o wide
kubectl get pods -A
```

There is **no SSH and no public API endpoint** — access is SSM-only by design.

**Watch the bootstrap** (if a fresh cluster seems slow):

```bash
# inside an SSM session on any node:
sudo tail -f /var/log/k8s-bootstrap.log
```

---

## How do I practice a lab?

The loop is **start → read → do → verify**:

```bash
# 1. Set up the lab's starting state (namespace + objects):
./scripts/lab-start.sh 05

# 2. Read the challenge:
cat labs/05-labels-selectors/README.md

# 3. Do the work (via the engine or your own SSM shell), then check:
./scripts/lab-verify.sh 05

# 4. On failure you get: FAILED / Object / one Hint (never the answer). Iterate.
```

Lab ids accept `05`, `5`, or `t01`. Available labs: **01–13** and **t01**.

**If you get stuck:** the answer is in `labs/<lab>/solution.md` — open it only
as a last resort (the verifier never prints it).

**Wipe and retry a lab from scratch:**

```bash
./scripts/lab-reset.sh 05
```

---

## How do I know what's done and what's pending?

Progress is tracked automatically in `PROGRESS.md` (in the repo, **not** in the
cluster — so it survives destroy/recreate):

```bash
make status        # cluster state + full progress table
make progress      # just the progress table
```

- `lab-start` → marks the lab **In Progress**
- `lab-verify` (fail) → bumps **Attempts**
- `lab-verify` (pass) → marks **Completed** with the date

---

## How do I stop paying when I'm not practicing?

| Situation | Command | Cost while away | Resume time |
|-----------|---------|-----------------|-------------|
| Break a few hours (same day) | `make pause` | ~$1.40/day (NAT+EBS) | `make resume`, ~2–3 min |
| Done for the day / longer | `make down` | **$0** | `make up`, ~8 min |

`make down` runs `terraform destroy` — the cheapest option, and **safe**: your
progress is in `PROGRESS.md`, and labs recreate their own in-cluster state next
time. Recommended default.

```bash
make pause     # stop EC2 (fast resume, small ongoing cost)
make resume    # start them again
make down      # destroy everything -> $0
make up        # rebuild fresh (~8 min) when you return
```

---

## How do I do a full practice session (recommended flow)?

```bash
make up                              # start session (~8 min)
make status                          # confirm nodes Ready
./scripts/lab-start.sh 01            # begin lab 01
# ...read labs/01-*/README.md, do the challenge...
./scripts/lab-verify.sh 01           # pass -> marked Completed
./scripts/lab-start.sh 02            # next lab
# ...continue through 02..13, t01...
make down                            # end session -> $0, progress remembered
```

Suggested order: **01 → 06** (fundamentals), then **07 → 13** (workloads), then
**t01** (troubleshooting).

---

## How do I troubleshoot the environment itself?

**`make up` seems stuck / nodes not Ready:**

```bash
make status
aws ssm start-session --region us-east-1 --target $(terraform -chdir=terraform output -raw control_plane_instance_id)
sudo tail -100 /var/log/k8s-bootstrap.log
sudo systemctl status kubelet
sudo crictl ps
```

**A worker didn't join:** check its bootstrap log the same way (worker ids via
`terraform -chdir=terraform output worker_instance_ids`). Workers wait for the
control-plane readiness marker in SSM Parameter Store, then join.

**Lab engine says "No running control-plane instance found":** the cluster is
stopped or destroyed — run `make resume` or `make up`.

**`aws ssm start-session` fails with a plugin error:** install the Session
Manager plugin (setup step 1).

---

## How do I clean up completely (stop all costs)?

```bash
make down                                    # destroys all cluster infra -> $0
```

The S3 state bucket is intentionally **not** destroyed by this (it holds your
Terraform state). To remove it too, after `make down`:

```bash
aws s3 rb s3://k8s-lab-tfstate-056793557731-us-east-1 --force
```

---

## Quick command reference

| Goal | Command |
|------|---------|
| Create cluster | `make up` |
| Check status + progress | `make status` |
| Pause (same-day break) | `make pause` / `make resume` |
| Destroy ($0) | `make down` |
| Start a lab | `./scripts/lab-start.sh <id>` |
| Verify a lab | `./scripts/lab-verify.sh <id>` |
| Reset a lab | `./scripts/lab-reset.sh <id>` |
| Open a node shell | `aws ssm start-session --region us-east-1 --target $(terraform -chdir=terraform output -raw control_plane_instance_id)` |
| Read a solution (last resort) | `cat labs/<lab>/solution.md` |
