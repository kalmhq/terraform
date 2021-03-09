# about

for debugging bluelight

main.tf is provided by user, the config depends on a existing PVC.

I tried 2 ways to setup a PVC:

1. manually setup a PVC using aws CloudFormation(see https://docs.aws.amazon.com/eks/latest/userguide/create-public-private-vpc.html#create-vpc)
2. setup a PVC using terraform (see commands below)

both failed to re-produce the problem the user has met.

# how to use

```sh
terraform init

# provision pvc
terraform apply -target=module.vpc

# provision remaining pieces
terraform apply
```
