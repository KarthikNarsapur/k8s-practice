# Lab 12 setup — nothing is deployed. You will create the Job yourself.
# The namespace ($NS) is already created by lab-start.sh.
info "Lab 12 deploys no starting workload."
info "Your task: create a Job 'pi' in namespace ${NS} that runs to completion."
info "It must complete 3 times (completions=3, parallelism=1)."
info "See README.md section 4 for the full challenge."

###############################################################################
# Hard Challenges — extra pre-deployed state for the advanced scenarios.
# These are OPTIONAL: the base challenge above still works on its own.
###############################################################################
info "Setting up hard-challenge resources..."

# HC1 — fail-job: a Job whose command always exits 1 (learner must fix it).
info "[HC1] Deploying Job 'fail-job' (intentionally failing command)..."
remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: fail-job
spec:
  completions: 1
  parallelism: 1
  backoffLimit: 4
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: fail
          image: busybox:1.36
          command: [\"sh\", \"-c\", \"echo failing; exit 1\"]
YAML"

# HC2 — backoff-job: a Job that exceeds its backoffLimit (learner must recreate).
info "[HC2] Deploying Job 'backoff-job' (exits 1, backoffLimit=3)..."
remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: backoff-job
spec:
  completions: 1
  parallelism: 1
  backoffLimit: 3
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: backoff
          image: busybox:1.36
          command: [\"sh\", \"-c\", \"exit 1\"]
YAML"

# HC3 — parallel-job: 5 completions running 3 at a time (should succeed).
info "[HC3] Deploying Job 'parallel-job' (completions=5, parallelism=3)..."
remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-job
spec:
  completions: 5
  parallelism: 3
  backoffLimit: 4
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: parallel
          image: busybox:1.36
          command: [\"sh\", \"-c\", \"echo done\"]
YAML"

ok "Hard-challenge Jobs deployed (fail-job, backoff-job, parallel-job)."
info "Investigate them: kubectl -n ${NS} get jobs ; kubectl -n ${NS} get pods"
