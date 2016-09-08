## Setup Bastion

cd terraform/aws
make all | grep box.bastion.public | awk '{ print $3 }'
52.88.107.17
ssh -i ~/.ssh/cf-deploy.pem ubuntu@52.88.107.17
jumpbox useradd
sudo -iu tbird
jumpbox user

LOCAL

cat ~/.ssh/id_rsa.pub | pbcopy

SERVER

mkdir ~/.ssh
vim ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

LOCAL

atom ~/.ssh/config

Host bastion
  Hostname 52.88.107.17
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
    access_key: (( vault "secret/aws:access_key" ))
    secret_key: (( vault "secret/aws:secret_key" ))
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
          subnet: subnet-4b17523d # <-- your AWS Subnet ID
          security_groups: [wide-open]
        reserved:
          - 10.4.1.2 - 10.4.1.3    # Amazon reserves these
            # proto-BOSH is in 10.4.1.0/28
          - 10.4.1.16 - 10.4.1.254 # Allocated to other deployments
        static:
          - 10.4.1.4

### build and run deploy

make manifest
make deploy

Path to existing bosh-init statefile (leave blank for new deployments):

PRESS ENTER

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

### config files

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
          subnet: subnet-4b17523d  # <--- your AWS Subnet ID
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
          subnet: subnet-b788aad3  # <--- your AWS Subnet ID
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
          subnet: subnet-72da602a  # <--- your AWS Subnet ID
          security_groups: [wide-open]
        reserved:
          - 10.4.3.2 - 10.4.3.3    # Amazon reserves these
          - 10.4.3.4 - 10.4.3.15   # Allocated to other deployments
            # Vault (z3) is in 10.4.3.16/28
          - 10.4.3.32 - 10.4.3.254 # Allocated to other deployments
        static:
          - 10.4.3.16 - 10.4.3.18

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
