# Kubernetes Learning Platform — convenience targets
#
# COST MODEL (personal, on/off):
#   make up      -> create everything          (~8 min; starts billing)
#   make down    -> destroy everything         ($0 between sessions)  <-- cheapest
#   make pause   -> stop EC2 (keep NAT+EBS)     (~$43/mo idle; fast resume)
#   make resume  -> start stopped EC2           (~2-3 min)
#   make status  -> show cluster + progress
#
# Progress (PROGRESS.md) lives in this repo, so it is remembered across
# up/down/pause/resume cycles.

REGION      ?= us-east-1
PROJECT     ?= k8s-lab
TF          := terraform -chdir=terraform

.PHONY: up down pause resume status progress nodes plan fmt validate destroy-confirm

up: ## Create the cluster (terraform apply)
	$(TF) init -input=false
	$(TF) apply -auto-approve
	@echo "Cluster creating. Give it ~5-8 min, then: make status"

down: ## Destroy ALL AWS resources ($0 between sessions). Progress is kept in PROGRESS.md.
	$(TF) destroy -auto-approve
	@echo "All AWS resources destroyed. PROGRESS.md is preserved in the repo."

pause: ## Stop EC2 to pause compute billing (NAT + EBS still bill)
	./scripts/aws-stop.sh

resume: ## Start previously-stopped EC2
	./scripts/aws-start.sh

status: ## Show node/cluster status and your lab progress
	@./scripts/lab-status.sh

progress: ## Show only the progress tracker
	@sed -n '/^| Lab /,/^$$/p' PROGRESS.md 2>/dev/null || cat PROGRESS.md

nodes: ## kubectl get nodes via SSM
	@./scripts/lab-verify.sh 01 >/dev/null 2>&1 || true
	@echo "Use: aws ssm start-session --region $(REGION) --target <cp-id>"

plan: ## terraform plan (read-only)
	$(TF) plan

fmt: ## terraform fmt
	$(TF) fmt -recursive

validate: ## terraform validate
	$(TF) init -backend=false -input=false >/dev/null && $(TF) validate
