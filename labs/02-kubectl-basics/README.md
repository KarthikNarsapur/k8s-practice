# Lab 02 — kubectl Basics

Level 1: Kubernetes Fundamentals

## 1. Objective

Become fluent with the day-to-day `kubectl` verbs you will use in every other
lab. By the end you will be able to discover the API surface, inspect objects
in multiple output formats, read a field's documentation without leaving the
terminal, and create objects imperatively.

Specifically you will practice:

- `kubectl get` with `-o wide`, `-o yaml`, `-o jsonpath`
- `kubectl describe`
- `kubectl explain` to discover object fields
- `kubectl api-resources` / `kubectl api-versions`
- `kubectl config` contexts and namespaces
- `--dry-run=client -o yaml` to generate manifests
- `kubectl annotate`

## 2. Prerequisites

- The cluster is deployed (`terraform apply`) and all nodes are Ready.
- You can open an SSM session to the control-plane node (see main README).
- Completed: Lab 01 (Cluster Architecture) recommended.

## 3. Environment Setup

```bash
./scripts/lab-start.sh 02
```

This is an inspection-and-creation lab. No workload is deployed for you — you
create the required object yourself inside the lab namespace `lab-02`.

## 4. Challenge

Work from an SSM session on the control-plane (or via the lab engine). All
objects go in the namespace `lab-02`.

1. Discover the API surface:
   - List every resource type the cluster knows about and note its short name
     and API group.
   - List the API versions the server serves.
2. Use `kubectl explain` to discover the structure of a Pod:
   - Find the field that sets the container image.
   - Find the field that holds pod-level annotations.
3. Create a pod named `kb-pod` using the image `nginx:1.25` in namespace
   `lab-02` **using a single imperative command** (not a YAML file you wrote by
   hand).
4. Inspect it three ways: `-o wide`, `-o yaml`, and `describe`. Note the node
   it landed on and its Pod IP.
5. Add the annotation `lab02/done=yes` to `kb-pod`.

Bonus (not verified): generate — but do NOT apply — a Deployment manifest with
`--dry-run=client -o yaml` and read it.

## 5. Expected Outcome

- A pod `kb-pod` (image `nginx:1.25`) is `Running` in namespace `lab-02`.
- `kb-pod` carries the annotation `lab02/done=yes`.
- You can explain, from memory, the difference between `-o wide`, `-o yaml`,
  and `describe`.

## 6. Verification Criteria

```bash
./scripts/lab-verify.sh 02
```

Passes when:
- Pod `kb-pod` exists in `lab-02` and is in phase `Running`.
- Pod `kb-pod` has the annotation `lab02/done=yes`.

## 7. Optional Hints

- `kubectl explain pod.spec.containers` drills into nested fields; append
  `--recursive` to see the whole tree.
- Imperative pod creation uses `kubectl run`.
- `kubectl annotate` adds metadata to an existing object without editing YAML.
- Remember to target the namespace with `-n lab-02` on every command.

## 8. Troubleshooting

- `kb-pod` stuck in `ContainerCreating` → give the image pull a moment, then
  `kubectl describe pod kb-pod -n lab-02` and read the Events section.
- `kubectl explain` returns "field not found" → check spelling and the dotted
  path; use `--recursive` to see valid children.
- Created the pod in the wrong namespace → delete it and recreate with
  `-n lab-02`, or set your context namespace.

## 9. Solution

The full solution is in `solution.md`. Try everything above first — open it
only if you are stuck.

## 10. Cleanup / Reset

```bash
./scripts/lab-reset.sh 02     # deletes the lab-02 namespace and restarts clean
./scripts/lab-destroy.sh 02   # removes lab state entirely
```
