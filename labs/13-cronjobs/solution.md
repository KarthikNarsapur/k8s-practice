# Lab 13 — Solution

> Spoiler. Only read this after attempting the challenge.

### 1. Create the CronJob
```bash
kubectl -n lab-13 create cronjob ticker \
  --image=busybox:1.36 \
  --schedule="*/1 * * * *" \
  -- sh -c "echo hello"
```

Or apply a manifest for full control:
```bash
cat <<'YAML' | kubectl apply -n lab-13 -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: ticker
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: ticker
              image: busybox:1.36
              command: ["sh", "-c", "echo hello"]
YAML
```

### 2. Wait ~1 minute for the first Job to fire
```bash
kubectl -n lab-13 get cronjob ticker
# LAST SCHEDULE fills in once it has run at least once.

kubectl -n lab-13 get jobs           # a ticker-<timestamp> Job appears each minute
kubectl -n lab-13 get pods           # its pod ends Completed
kubectl -n lab-13 logs job/<ticker-job-name>   # prints 'hello'
kubectl -n lab-13 describe cronjob ticker
```

### 3. Suspend it (pause without deleting)
```bash
kubectl -n lab-13 patch cronjob ticker --type=merge -p '{"spec":{"suspend":true}}'

# Confirm:
kubectl -n lab-13 get cronjob ticker -o jsonpath='{.spec.suspend}{"\n"}'
# -> true
```
While suspended, the CronJob keeps its history but creates no new Jobs.

### Verify
```bash
./scripts/lab-verify.sh 13
```

### Why it matters
A CronJob is a controller that creates a Job on a cron schedule (standard
five-field cron syntax; `*/1 * * * *` = every minute). It records
`status.lastScheduleTime` after each firing and keeps a bounded history via
`successfulJobsHistoryLimit` / `failedJobsHistoryLimit`. Setting
`spec.suspend: true` pauses scheduling without deleting the object — the
standard way to stop a recurring task temporarily. The verifier confirms the
CronJob exists, fired at least once, and is now suspended.
