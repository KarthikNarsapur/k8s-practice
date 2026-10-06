# Lab 13 setup — nothing is deployed. You will create the CronJob yourself.
# The namespace ($NS) is already created by lab-start.sh.
info "Lab 13 deploys no starting workload."
info "Your task: create a CronJob 'ticker' in namespace ${NS} (schedule '*/1 * * * *')."
info "Wait ~1 minute for it to spawn at least one Job, then suspend it."
info "See README.md section 4 for the full challenge."

###############################################################################
# Hard Challenges — extra pre-deployed state for the advanced scenarios.
# These are OPTIONAL: the base challenge above still works on its own.
###############################################################################
info "Setting up hard-challenge resources..."

# HC1 — slow-tick: a CronJob whose Job runs longer (90s) than its 1-minute
#        interval, with concurrencyPolicy=Allow, so Jobs overlap.
info "[HC1] Deploying CronJob 'slow-tick' (sleep 90, concurrencyPolicy=Allow)..."
remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: slow-tick
spec:
  schedule: \"*/1 * * * *\"
  concurrencyPolicy: Allow
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: slow
              image: busybox:1.36
              command: [\"sh\", \"-c\", \"sleep 90\"]
YAML"

# HC2 — policy-allow vs policy-forbid: identical long-running jobs, different
#        concurrencyPolicy, so the learner can compare overlap behavior.
info "[HC2] Deploying CronJob 'policy-allow' (concurrencyPolicy=Allow)..."
remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: policy-allow
spec:
  schedule: \"*/1 * * * *\"
  concurrencyPolicy: Allow
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: worker
              image: busybox:1.36
              command: [\"sh\", \"-c\", \"sleep 120\"]
YAML"

info "[HC2] Deploying CronJob 'policy-forbid' (concurrencyPolicy=Forbid)..."
remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: policy-forbid
spec:
  schedule: \"*/1 * * * *\"
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: worker
              image: busybox:1.36
              command: [\"sh\", \"-c\", \"sleep 120\"]
YAML"

# HC3 — broken-cron: suspended from the start AND a failing command. Learner
#        must unsuspend it and fix the command so a child Job succeeds.
info "[HC3] Deploying CronJob 'broken-cron' (suspended + failing command)..."
remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: broken-cron
spec:
  schedule: \"*/1 * * * *\"
  suspend: true
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: broken
              image: busybox:1.36
              command: [\"sh\", \"-c\", \"exit 1\"]
YAML"

ok "Hard-challenge CronJobs deployed (slow-tick, policy-allow, policy-forbid, broken-cron)."
info "Investigate them: kubectl -n ${NS} get cronjobs ; kubectl -n ${NS} get jobs"
