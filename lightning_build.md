# Lightning Build

## Pre-requisites

* A configured `aws.tfvars` file that allows Terraform to quickly build and destroy
* IAM Deploy user, with Access Key and Secret Key
* IAM SHIELD user, with Access Key and Secret Key

## Setup Bastion

LOCAL
cd terraform/aws
(5 min)
make all | grep box.bastion.public | awk '{ print $3 }'

OBTAIN IP ADDRESS, replace IP_ADDR

ssh -i ~/.ssh/cf-deploy.pem ubuntu@IP_ADDR

SERVER

jumpbox useradd
sudo -iu tbird
jumpbox user

NEW TAB LOCAL

ssh -i ~/.ssh/cf-deploy.pem ubuntu@IP_ADDR

SERVER

sudo -iu tbird
mkdir ~/.ssh
vim ~/.ssh/authorized_keys

LOCAL

cat ~/.ssh/id_rsa.pub | pbcopy

SERVER

chmod 600 ~/.ssh/authorized_keys

LOCAL

atom ~/.ssh/config

Host bastion
  Hostname IP_ADDR
  User tbird

## vault-init

IN A SEPARATE TAB

vault server -dev

safe target init http://127.0.0.1:8200
safe targets
safe auth token

INSERT ROOT TOKEN

safe set secret/handshake knock=knock
safe read secret/handshake

## proto-BOSH

mkdir -p ~/ops
cd ~/ops

### generate deploy with genesis

genesis new deployment --template bosh
cd ~/ops/bosh-deployments
genesis new site --template aws us-west-2
genesis new env --type bosh-init us-west-2 proto

ANSWER yes

cd ~/ops/bosh-deployments/us-west-2/proto

### store values in vault

safe set secret/us-west-2 access_key secret_key

INPUT VALUES

safe ssh secret/us-west-2/proto/shield/keys/core

### copy key to bastion

LOCAL
cat ~/.ssh/cf-deploy.pem | pbcopy

SERVER
vim ~/.ssh/cf-deploy.pem

### configure environment files

vim properties.yml

---
meta:
  aws:
    region: us-west-2
    azs:
      z1: (( concat meta.aws.region "a" ))
    access_key: (( vault "secret/us-west-2:access_key" ))
    secret_key: (( vault "secret/us-west-2:secret_key" ))
    private_key: ~/.ssh/cf-deploy.pem
    ssh_key_name: cf-deploy
    default_sgs:
      - restricted

vim credentials.yml

---
meta:
  shield_public_key: (( vault "secret/us-west-2/proto/shield/keys/core:public" ))

GET SUBNET FROM console
https://us-west-2.console.aws.amazon.com/vpc/home?region=us-west-2#subnets:filter=global-infra-0

vim networking.yml

---
networks:
  - name: default
    subnets:
      - range:    10.4.1.0/24
        gateway:  10.4.1.1
        dns:     [10.4.0.2]
        cloud_properties:
          subnet: subnet-02e3a274 # <-- your AWS Subnet ID
          security_groups: [wide-open]
        reserved:
          - 10.4.1.2 - 10.4.1.3    # Amazon reserves these
            # proto-BOSH is in 10.4.1.0/28
          - 10.4.1.16 - 10.4.1.254 # Allocated to other deployments
        static:
          - 10.4.1.4

### build and run deploy

make manifest
(26 mins)
make deploy

PRESS ENTER Path to existing bosh-init statefile (leave blank for new deployments):

### login to proto-BOSH

safe get secret/us-west-2/proto/bosh/users/admin

COPY PASSWORD

bosh target https://10.4.1.4:25555 proto-bosh

## Vault in proto

cd ~/ops
genesis new deployment --template vault
cd ~/ops/vault-deployments

genesis new site --template aws us-west-2
genesis new env us-west-2 proto

SELF-SIGNED CERT yes
TARGETING INIT yes

FQDN vault.tylerbird.com

### deployment config files

cd ~/ops/vault-deployments/us-west-2/proto

vim properties.yml

---
meta:
  aws:
    region: us-west-2
    azs:
      z1: (( concat meta.aws.region "a" ))
      z2: (( concat meta.aws.region "b" ))
      z3: (( concat meta.aws.region "c" ))
properties:
  vault:
    ha:
      domain: 10.4.1.16

vim networking.yml

REPLACE SUBNETS
https://us-west-2.console.aws.amazon.com/vpc/home?region=us-west-2#subnets:filter=global-infra

---
networks:
  - name: vault_z1
    subnets:
      - range:    10.4.1.0/24
        gateway:  10.4.1.1
        dns:     [10.4.0.2]
        cloud_properties:
          subnet: subnet-02e3a274  # <--- your AWS Subnet ID
          security_groups: [wide-open]
        reserved:
          - 10.4.1.2 - 10.4.1.3    # Amazon reserves these
          - 10.4.1.4 - 10.4.1.15   # Allocated to other deployments
            # Vault (z1) is in 10.4.1.16/28
          - 10.4.1.32 - 10.4.1.254 # Allocated to other deployments
        static:
          - 10.4.1.16 - 10.4.1.18

  - name: vault_z2
    subnets:
      - range:    10.4.2.0/24
        gateway:  10.4.2.1
        dns:     [10.4.2.2]
        cloud_properties:
          subnet: subnet-8cd751d4  # <--- your AWS Subnet ID
          security_groups: [wide-open]
        reserved:
          - 10.4.2.2 - 10.4.2.3    # Amazon reserves these
          - 10.4.2.4 - 10.4.2.15   # Allocated to other deployments
            # Vault (z2) is in 10.4.2.16/28
          - 10.4.2.32 - 10.4.2.254 # Allocated to other deployments
        static:
          - 10.4.2.16 - 10.4.2.18

  - name: vault_z3
    subnets:
      - range:    10.4.3.0/24
        gateway:  10.4.3.1
        dns:     [10.4.3.2]
        cloud_properties:
          subnet: subnet-c1e5cca5  # <--- your AWS Subnet ID
          security_groups: [wide-open]
        reserved:
          - 10.4.3.2 - 10.4.3.3    # Amazon reserves these
          - 10.4.3.4 - 10.4.3.15   # Allocated to other deployments
            # Vault (z3) is in 10.4.3.16/28
          - 10.4.3.32 - 10.4.3.254 # Allocated to other deployments
        static:
          - 10.4.3.16 - 10.4.3.18

make manifest
(10 mins)
make deploy

### initialize global vault

export VAULT_ADDR=https://10.4.1.16:8200
export VAULT_SKIP_VERIFY=1

vault init
vault unseal
vault unseal
vault unseal
safe target https://10.4.1.16:8200 proto
safe auth token

INSERT ROOT TOKEN

safe set secret/handshake knock=knock
safe read secret/handshake

### migrate credentials

safe targets

BEFORE

safe target proto -- tree

safe target init -- export secret | \
  safe target proto -- import

AFTER

safe target proto -- tree

sudo pkill vault

## SHIELD

cd ~/ops
genesis new deployment --template shield
cd ~/ops/shield-deployments

genesis new site --template aws us-west-2
genesis new env us-west-2 proto
cd ~/ops/shield-deployments/us-west-2/proto

### deployment config files

vim networking.yml

---
networks:
  - name: shield
    subnets:
      - range:    10.4.1.0/24
        gateway:  10.4.1.1
        dns:     [10.4.0.2]
        cloud_properties:
          subnet: subnet-02e3a274  # <--- your AWS Subnet ID
          security_groups: [wide-open]
        reserved:
          - 10.4.1.2 - 10.4.1.3    # Amazon reserves these
          - 10.4.1.4 - 10.4.1.31   # Allocated to other deployments
            # SHIELD is in 10.4.1.32/28
          - 10.4.1.48 - 10.4.1.254 # Allocated to other deployments
        static:
          - 10.4.1.32 - 10.4.1.34

vim properties.yml

---
meta:
  az: us-west-2a

properties:
  shield:
    skip_ssl_verify: true
    store:
      name: "default"
      plugin: "s3"
      config:
        access_key_id: (( vault "secret/us-west-2/proto/shield/aws:access_key" ))
        secret_access_key: (( vault "secret/us-west-2/proto/shield/aws:secret_key" ))
        bucket: tbird-codex-backups # <- backup's s3 bucket
        prefix: "/"
    schedule:
      name: "default"
      when: "daily 3am"
    retention:
      name: "default"
      expires: "86400" # 24 hours

vim credentials.yml

---
properties:
  shield:
    daemon:
      ssh_private_key: (( vault meta.vault_prefix "/keys/core:private"))

make manifest
(12 min)
make deploy

### Accessing SHIELD

LOCAL NEW TAB

ssh tbird@IP_ADDR -L 8443:10.4.1.32:443

safe get secret/us-west-2/proto/shield/webui

open https://localhost:8443/
