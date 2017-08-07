# Infrastructure

The infrastructure control repository for our AWS

Uses Terraform mainly to control.

---

## Set up your credentials
Put `access_key` and `secret_key` in `~/.aws/credentials`

Or you can put your credentials in `terraform.tfvars`.

## Prerequisite

Download [Terraform](https://www.terraform.io/)

> **Warning:** Terraform version (0.9.6 below) without [provider/aws: Revoke default ipv6 egress rule for aws_security_group](https://github.com/hashicorp/terraform/pull/15075) patch is required.

## Deploy
```
make
```

## Roadmap
- [x] VPC and internet gateway
- [x] IAM role
- [x] Security groups (master, worker and etc)
- [x] kubernetes machines setup (with coreOS_v1407) (master, worker, and etcd)
- [x] certificates generate
- [x] kubernetes setup: remote (hyperkube and etc)
- [x] kubernetes setup: local (kubectl)
- [x] Essential addons: dns, dashboard, heapster
- [x] Using AWS EC2 Container Registry
- [ ] Ingress Controller for ALB
- [ ] Security Group with minimal policies
- [ ] Monitoring with Prometheus
- [ ] Logging with Fluentd and cloudwatch
- [ ] Kubernetes upgrade mechanism
- [ ] rkt as container runtime
