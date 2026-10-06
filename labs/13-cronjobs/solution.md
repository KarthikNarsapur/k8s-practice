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

---

## Hard Challenge Solutions

> Spoiler. Only read these after attempting the hard challenges. `lab-start.sh`
> pre-deploys `slow-tick`, `policy-allow`, `policy-forbid`, and `broken-cron`;
> HC1/HC2 are observational, and for HC3 you must repair `broken-cron`. The
> verifier re-checks all of them.

### Hard Challenge 1 — Concurrent CronJobs

> `slow-tick` fires every minute but each Job runs `sleep 90`, so a run is still
> going when the next one is scheduled. With `concurrencyPolicy: Allow`, they
> overlap.

```bash
# Watch overlap build up over 2-3 minutes.
kubectl -n lab-13 get cronjob slow-tick            # ACTIVE climbs above 1
kubectl -n lab-13 get jobs                         # multiple slow-tick-<ts> Jobs
kubectl -n lab-13 get pods -w                      # several Running at once
kubectl -n lab-13 describe cronjob slow-tick       # Last Schedule Time, Active jobs
```

**Why it matters:** A CronJob's schedule and its Job duration are independent. If
a Job runs longer than the interval, the next fire arrives mid-run. The default
`concurrencyPolicy: Allow` starts the new Job anyway, so long jobs on a tight
schedule pile up — a classic cause of runaway pod counts. Recognizing overlap is
the first step to choosing a safer policy.

### Hard Challenge 2 — concurrencyPolicy

> `policy-allow` and `policy-forbid` have identical `sleep 120` jobs on a
> one-minute schedule; only their `concurrencyPolicy` differs.

```bash
# Compare over ~3 minutes.
kubectl -n lab-13 get cronjob policy-allow policy-forbid
# policy-allow:  ACTIVE grows (2, 3, ...) — overlapping runs accumulate.
# policy-forbid: ACTIVE stays at 1 — new runs are skipped while one is active.

kubectl -n lab-13 get jobs | grep policy-allow     # many Jobs
kubectl -n lab-13 get jobs | grep policy-forbid    # far fewer Jobs
kubectl -n lab-13 describe cronjob policy-forbid    # Events note skipped schedules
```

**Why it matters:** `concurrencyPolicy` is the knob that decides overlap
behavior. `Allow` (default) runs everything concurrently; `Forbid` protects a
job that must never run twice at once (e.g. a non-idempotent batch) by skipping
the overlapping schedule; `Replace` cancels the running Job and starts fresh.
Picking the right policy is how you keep a slow recurring task from either
stampeding or silently skipping work.

### Hard Challenge 3 — CronJob Forensics

> `broken-cron` ships `suspend: true` *and* a failing command (`exit 1`). Two
> independent problems: it never schedules, and even if it did, its Jobs would
> fail.

```bash
# Diagnose.
kubectl -n lab-13 get cronjob broken-cron                 # SUSPEND = True, no runs
kubectl -n lab-13 get cronjob broken-cron -o jsonpath='{.spec.suspend}{"\n"}'
kubectl -n lab-13 describe cronjob broken-cron            # command exits 1
```

Fix both problems. The cleanest route is to re-apply the full spec with
`suspend: false` and a working command:
```bash
cat <<'YAML' | kubectl apply -n lab-13 -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: broken-cron
spec:
  schedule: "*/1 * * * *"
  suspend: false
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: broken
              image: busybox:1.36
              command: ["sh", "-c", "echo fixed; exit 0"]
YAML

# Wait up to ~60s for the next scheduled Job, then confirm a success:
kubectl -n lab-13 get jobs | grep broken-cron
kubectl -n lab-13 get jobs -o jsonpath='{range .items[*]}{.metadata.name}{" succeeded="}{.status.succeeded}{"\n"}{end}' | grep broken-cron
```

Alternatively, patch to unsuspend and patch the command separately:
```bash
kubectl -n lab-13 patch cronjob broken-cron --type=merge -p '{"spec":{"suspend":false}}'
kubectl -n lab-13 patch cronjob broken-cron --type=merge \
  -p '{"spec":{"jobTemplate":{"spec":{"template":{"spec":{"containers":[{"name":"broken","image":"busybox:1.36","command":["sh","-c","echo fixed; exit 0"]}]}}}}}}'
```

**Why it matters:** Real incidents often have more than one root cause. Here a
suspended CronJob produces no Jobs *and* a bad command would fail any Job it did
produce — fixing only one leaves it broken. The forensic habit is to check both
the controller's own state (`suspend`, schedule, events) and the workload it
produces (child Jobs, pod exit codes), then correct every cause before expecting
success.
