#!/usr/bin/env bash
set -euo pipefail
info "Lab 15: deploy sample workloads, four broken HC Services, and an in-cluster DNS client."
remote_exec "cat <<'YAML' | kubectl apply -n ${NS} -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-a
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-a
  template:
    metadata:
      labels:
        app: app-a
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-b
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-b
  template:
    metadata:
      labels:
        app: app-b
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-c
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-c
  template:
    metadata:
      labels:
        app: app-c
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-d
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-d
  template:
    metadata:
      labels:
        app: app-d
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-e
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-e
  template:
    metadata:
      labels:
        app: app-e
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-f
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-f
  template:
    metadata:
      labels:
        app: app-f
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-g
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-g
  template:
    metadata:
      labels:
        app: app-g
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-h
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-h
  template:
    metadata:
      labels:
        app: app-h
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: hc-dns-e
spec:
  selector:
    app: missing-e
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: hc-dns-f
spec:
  selector:
    app: app-f
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: hc-dns-g
spec:
  selector:
    app: missing-g
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: hc-dns-h
spec:
  selector:
    app: app-h
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: v1
kind: Pod
metadata:
  name: dns-client
spec:
  restartPolicy: Never
  containers:
  - name: client
    image: busybox:1.36
    command: ["sh","-c","sleep 36000"]
---
YAML"
ok "Setup complete. Finish all four basic and four hard challenges in README.md."
