# Lab 12 — Jobs

Level 2: Workloads

## 1. Objective

Understand batch workloads: a Job runs pods until a set number of successful
completions is reached. By the end you will be able to create a Job, control it
with `completions`, `parallelism`, and `backoffLimit`, and read its status and
logs to confirm it finished.

## 2. Prerequisites

- The cluster is deployed and all nodes are `Ready`.
- You can open an SSM session to the control-plane node (see main README).
- Completed: Lab 11 (DaemonSets) and a basic understanding of pods and restart
  policies.

## 3. Environment Setup

```bash
./scripts/lab-start.sh 12
```

This lab deploys **nothing**. You create the Job yourself in the `lab-12`
namespace.

## 4. Challenge

Work in the `lab-12` namespace.

1. Create a Job named `pi` that:
   - uses image `busybox:1.36`,
   - runs a deterministic command that exits 0, e.g. `sh -c "echo done"`,
   - has `completions: 3` and `parallelism: 1` (three successful runs, one at a
     time),
   - uses `restartPolicy: Never` (or `OnFailure`).
2. Watch it progress and finish:
   ```bash
   kubectl -n lab-12 get jobs -w
   kubectl -n lab-12 get pods
   ```
3. Inspect the output and metadata:
   ```bash
   kubectl -n lab-12 logs job/pi
   kubectl -n lab-12 describe job pi
   ```

### Hard Challenges

These build on the base lab. `./scripts/lab-start.sh 12` pre-deploys the Jobs
below. Investigate them in the `lab-12` namespace with
`kubectl -n lab-12 get jobs` and `kubectl -n lab-12 get pods`.

**HC1 — Job Failure Investigation.** Setup deploys a Job `fail-job` whose
command always exits 1. It will keep failing up to its `backoffLimit`.
- Investigate: read the pod logs, exit codes, events, and Job status.
- **Fix it:** delete `fail-job` and recreate it with a command that exits 0 so
  it succeeds.

**HC2 — backoffLimit.** Setup deploys a Job `backoff-job` (command `exit 1`,
`backoffLimit: 3`). It will exhaust retries and be marked Failed.
- Observe the retry pattern: pods appear with increasing back-off delays; once
  `backoffLimit` is reached the Job stops creating new pods.
- **Fix it:** delete `backoff-job` and recreate it with a working command so it
  completes successfully.

**HC3 — Parallelism and Completions.** Setup deploys a Job `parallel-job` with
`completions: 5` and `parallelism: 3` (a valid, succeeding command).
- Watch it progress: up to 3 pods run concurrently until 5 completions are
  reached.
- Describe the Job and compare `active`, `succeeded`, and `failed` counters.

## 5. Expected Outcome

- Job `pi` in `lab-12` reaches `COMPLETIONS 3/3`.
- Three pods run one after another and end in `Completed`.
- `kubectl logs job/pi` shows the command output.
- **HC1:** `fail-job` exists and `status.succeeded >= 1` (you fixed the
  command).
- **HC2:** `backoff-job` exists and `status.succeeded >= 1` (you recreated it
  with a working command).
- **HC3:** `parallel-job` reaches `COMPLETIONS 5/5`.

## 6. Verification Criteria

```bash
./scripts/lab-verify.sh 12
```

Passes when:
- Job `pi` in `lab-12` has `status.succeeded == 3`.
- **HC1:** Job `fail-job` exists and `status.succeeded >= 1`.
- **HC2:** Job `backoff-job` exists and `status.succeeded >= 1`.
- **HC3:** Job `parallel-job` exists and `status.succeeded == 5`.

## 7. Optional Hints

- `kubectl create job pi --image=busybox:1.36 -- sh -c "echo done"` scaffolds a
  Job, but its generator defaults to `completions: 1`.
- `completions` = required successes; `parallelism` = how many pods run at once;
  `backoffLimit` = how many retries before the Job is marked Failed.
- `restartPolicy: Always` is invalid for a Job — use `Never` or `OnFailure`.
- **HC1/HC2:** A Job's pod template is immutable, so you cannot patch the broken
  command in place — delete the Job and recreate it (same name) with a command
  that exits 0.
- **HC2:** `backoffLimit` bounds how many pod failures are tolerated before the
  Job itself is marked `Failed` and stops retrying — watch the failures climb
  with `kubectl -n lab-12 get pods -w`.
- **HC3:** `parallelism` caps how many pods run at once; `completions` is the
  total successes required. With 3 and 5, three run concurrently until five have
  succeeded.

## 8. Troubleshooting

- Job stuck at `0/3` → `kubectl -n lab-12 describe job pi` and check the pods'
  status; a bad command or image keeps completions from succeeding.
- `field is immutable` when patching `completions` → delete the Job and
  re-create it with the desired spec (a Job's completion settings are fixed).
- Pods `Error` instead of `Completed` → your command exited non-zero; make sure
  it returns 0.

## 9. Solution

The full solution is in `solution.md`. Try everything above first — open it
only if you are stuck.

## 10. Cleanup / Reset

```bash
./scripts/lab-reset.sh 12     # deletes the lab-12 namespace, starts fresh
./scripts/lab-destroy.sh 12   # removes lab state entirely
```
