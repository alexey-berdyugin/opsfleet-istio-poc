## Introduction
I have experience of multiple services deployment with independent IAM roles and practically ready solution. 
So I choose second task with Istio, also because I haven't got real experience with Istio and it was interesting for me. 
Day of documentations reading, testing and troubleshooting brought some light on it.

## Overview

Repository contain POC for mTLS demo according to Opsfleet test task. 

It demonstrates mTLS connection between few containers deployed in Kubernetes cluster.

Terraform deployed separate Kubernetes namespace with enforced mTLS option and `istio-injection`. 
So further it is sufficient to deploy any services in current namespace and traffic will go via sidecar istio-proxy containers. 

```
kubectl describe ns mtls-enforced
Name:         mtls-enforced
Labels:       istio-injection=enabled
              kubernetes.io/metadata.name=mtls-enforced

kubectl get peerauthentication -n mtls-enforced
NAME      MODE     AGE
default   STRICT   27h
```

## Requirements 
- kubectl
- Helm
- Docker
- AWS CLI
- Docker registry (ECR)

## POC instruction
### 1. Setup local environment
- install requirements
- Configure access to AWS account where infrastructure with EKS cluster deployed
- Setup kubectl config
- Create ECR registry (sorry, forgot to add it in terraform)

### 2. Build test application image 
From repository root folder:
```
docker build -t test-app .
docker login
docker tag test-app %ECR_REPO%:tag
docker push %ECR_REPO%:tag
```

### 3. Deploy test application in EKS cluster via Helm
1. Update `apps.image.repository` value in `./helm-chart/values.yaml` file
2. Deploy multiple instances of test application

```
helm install mtls-test-app1 ./helm-chart -f ./mtls-test.app1.yaml -n mtls-enforced
helm install mtls-test-app2 ./helm-chart -f ./mtls-test.app2.yaml -n mtls-enforced
helm install non-mtls-test-app ./helm-chart
```

### 4. Verification of connections between deployed test applications
We deployed 2 test applications in mtls-enforced namespace and one in default non-mTLS namespace.

The following aliases configured:
```
alias k=kubectl
alias km=kubectl * -n mtls-enforced
```

1. Request HTTP from mtls-test-app1 to non-mtls-test-app, we should receive 200
```
km exec $(km get pod -l app.kubernetes.io/instance=mtls-test-app1 -o json | jq -r '.items[0].metadata.name') -c app -- /bin/sh -c \
"curl http://$(k describe svc -l app.kubernetes.io/instance=non-mtls-test-app | grep Endpoints | awk '{print $2}')/test.html"
This static HTML file is served by Nginx
```
2. Request HTTPS from mtls-test-app1 to non-mtls-test-app
```
km exec $(km get pod -l app.kubernetes.io/instance=mtls-test-app1 -o json | jq -r '.items[0].metadata.name') -c app -- /bin/sh -c \
"curl https://$(k describe svc -l app.kubernetes.io/instance=non-mtls-test-app | grep Endpoints | awk '{print $2}')/test.html"
This static HTML file is served by Nginx
curl: (35) error:0A00010B:SSL routines::wrong version number
command terminated with exit code 35
```
3. Request HTTP from mtls-test-app1 to mtls-test-app2
```
km exec $(km get po -l app.kubernetes.io/instance=mtls-test-app1 -o json | jq -r '.items[0].metadata.name') -c app -- /bin/sh -c \
"curl http://mtls-test-app2:8080/test.html"
This static HTML file is served by Nginx
```
4. Request HTTPS from mtls-test-app1 to mtls-test-app2
```
km exec $(km get po -l app.kubernetes.io/instance=mtls-test-app1 -o json | jq -r '.items[0].metadata.name') -c app -- /bin/sh -c \
"curl https://mtls-test-app2:8080/test.html"
curl: (60) SSL certificate problem: self-signed certificate in certificate chain
More details here: https://curl.se/docs/sslcerts.html

curl failed to verify the legitimacy of the server and therefore could not
establish a secure connection to it. To learn more about this situation and
how to fix it, please visit the web page mentioned above.
command terminated with exit code 60
```
5. Request HTTP from mtls-test-app2 to mtls-test-app1
```
km exec $(km get po -l app.kubernetes.io/instance=mtls-test-app2 -o json | jq -r '.items[0].metadata.name') -c app -- /bin/sh -c \
"curl http://mtls-test-app1:8080/test.html"
This static HTML file is served by Nginx
```

POC completed.