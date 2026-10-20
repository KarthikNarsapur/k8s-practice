# Lab 19 — Networking Troubleshooting Capstone

Level: Networking professional / troubleshooting

## Objective
Diagnose end-to-end Service connectivity across selectors, target ports, ready endpoints, DNS, and HTTP response. Setup intentionally breaks all eight Service paths.

## Start
```bash
./scripts/lab-start.sh 19
```

## Four basic challenges
Repair `incident-a`, `incident-b`, `incident-c`, and `incident-d`. Each must select its matching `app=app-a` through `app=app-d`, map Service port 80 to targetPort 80, have ready endpoints, resolve in DNS, and serve HTTP from `netprobe`.

## Four hard challenges
Repair `hc-incident-e`, `hc-incident-f`, `hc-incident-g`, and `hc-incident-h` with the same end-to-end criteria for their matching workload labels.

## Investigate
```bash
kubectl -n lab-19 get deploy,pods,svc,endpointslices
kubectl -n lab-19 get pods --show-labels
kubectl -n lab-19 describe service <name>
kubectl -n lab-19 exec netprobe -- nslookup incident-a
kubectl -n lab-19 exec netprobe -- wget -S -T 5 -O /dev/null http://incident-a
kubectl -n lab-19 get events --sort-by=.lastTimestamp
```

## Verify
```bash
./scripts/lab-verify.sh 19
```
The verifier checks structured Service fields, ready endpoint addresses, DNS lookup, and HTTP connectivity. It reports the first failing condition and one conceptual hint without exposing the fix.

Reset: `./scripts/lab-reset.sh 19`. Solution: `solution.md`.
