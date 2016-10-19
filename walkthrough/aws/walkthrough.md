# AWS Codex Walkthrough

(( insert_file overview.md ))

## Setup Credentials

So you've got an AWS account right?  Cause otherwise let me interest you in
another guide like our OpenStack, Azure or vSphere, etc.  j/k  

To begin, let's login to [Amazon Web Services][aws] and prepare the necessary
credentials and resources needed.

1. Access Key ID
2. Secret Key ID
3. A Name for your VPC
4. An EC2 Key Pair

### Generate Access Key

  The first thing you're going to need is a combination **Access Key ID** /
  **Secret Key ID**.  These are generated (for IAM users) via the IAM dashboard.

  To help keep things isolated, we're going to set up a brand new IAM user.  It's
  a good idea to name this user something like `cf` so that no one tries to
  re-purpose it later, and so that it doesn't get deleted.

1. On the AWS web console, access the IAM service, and click on `Users` in the
sidebar.  Then create a new user and select "Generate an access key for each user".

  **NOTE**: **Make sure you save the secret key somewhere secure**, like 1Password
  or a Vault instance.  Amazon will be unable to give you the **Secret Key ID**
  if you misplace it -- your only recourse at that point is to generate a new
  set of keys and start over.

2. Next, find the `cf` user and click on the username. This should bring up a
summary of the user with things like the _User ARN_, _Groups_, etc.  In the
bottom half of the Summary panel, you can see some tabs, and one of those tabs
is _Permissions_.  Click on that one.

3. Now assign the **PowerUserAccess** role to your user. This user will be able to
do any operation except IAM operations.  You can do this by clicking on the
_Permissions_ tab and then clicking on the _attach policy_ button.

4. We will also need to create a custom user policy in order to create ELBs with
SSL listeners. At the same _Permissions_ tab, expand the _Inline Policies_ and
then create one using the _Custom Policy_ editor. Name it `ServerCertificates`
and paste the following content:

    ```
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "iam:DeleteServerCertificate",
                    "iam:UploadServerCertificate",
                    "iam:ListServerCertificates",
                    "iam:GetServerCertificate"
                ],
                "Resource": "*"
            }
        ]
    }
    ```

5. Click on _Apply Policy_ and you will be all set.

### Name Your VPC

This step is really simple -- just make one up.  The VPC name will be used to
prefix certain things that Terraform creates in the AWS Virtual Private Cloud.
When managing multiple VPC's this can help you to sub-select only the ones you're
concerned about.

The VPC is configured in Terraform using the `aws_vpc_name` variable in the
`aws.tfvars` file we're going to create soon.

```
aws_vpc_name = "snw"
```

The prefix of `snw` for Stark & Wayne would show up before VPC components like
Subnets, Network ACLs and Security Groups:

| Name            | ID              |
| :-------------- | :-------------- |
| snw-dev-infra-0 | subnet-cf7812b9 |
| snw-hardened    | acl-10feff74    |
| snw-dmz         | sg-e0cfcf86     |

### Generate EC2 Key Pair

The **Access Key ID** / **Secret Key ID** are used to get access to the Amazon
Web Services themselves.  In order to properly deploy on EC2 over SSH, we'll need
to create an **EC2 Key Pair**.  This will be used as we bring up the initial NAT
and bastion host instances. And is the SSH key you'll use to connect from your
local machine to the bastion.

**NOTE**: Make sure you are in the correct region (top-right corner of the black
menu bar) when you create your **EC2 Key Pair**. Otherwise, it just plain won't
work. The region name setting can be found in `aws.tf` and the mapping to the
region in the menu bar can be found on [Amazon Region Doc][amazon-region-doc].

1. Starting from the main Amazon Web Console, go to Service > EC2, and then click
the _Key Pairs_ link under _Network & Security_. Look for the big blue
`Create Key Pair` button.

2. This downloads a file matching the name of your **EC2 Key Pair**.  Example,
a key pair named cf-deploy would produce a file named `cf-deploy.pem` and be saved
to your Downloads folder.  Also `chmod 0600` the `*.pem` file.

3. Decide where you want this file to be.  All `*.pem` files are ignored in the
codex repository.  So you can either move this file to the same folder as
`CODEX_ROOT/tefrraform/aws` or move it to a place you keep SSH keys and use the
full path to the `*.pem` file in your `aws.tfvars` for the `aws_key_file`
variable name.

```
aws_key_file = /Users/<username>/.ssh/cf-deploy.pem
```

## Use Terraform

Once the requirements for AWS are met, we can put it all together and build out
your shiny new Virtual Private Cloud (VPC), NAT server and bastion host. Change
to the `terraform/aws` sub-directory of this repository before we begin.

The configuration directly matches the [Network Plan][netplan] for the demo
environment.  When deploying in other environments like production, some tweaks
or rewrites may need to be made.

### Variable File

Create a `aws.tfvars` file with the following configurations (substituting your
actual values) all the other configurations have default setting in the
`CODEX_ROOT/terraform/aws/aws.tf` file.

```
aws_access_key = "..."
aws_secret_key = "..."
aws_vpc_name   = "snw"
aws_key_name   = "cf-deploy"
aws_key_file   = "/Users/<username/.ssh/cf-deploy.pem"
```

If you need to change the region or subnet, you can override the defaults
by adding:

```
aws_region     = "us-east-1"
network        = "10.42"
```

Also, be advised:  Depending on the state of your AWS account, you may also need to explicitly list the AWS Availability Zones as follows:
```
aws_az1        = "a"
aws_az2        = "c"
aws_az3        = "d"
```
Otherwise, you may get the following error:
```
 * aws_subnet.dev-cf-edge-1: Error creating subnet: InvalidParameterValue: Value (us-east-1b) for parameter availabilityZone is invalid. Subnets can currently only be created in the following availability zones: us-east-1c, us-east-1d, us-east-1e, us-east-1a.
    status code: 400, request id:
```
You may change some default settings according to the real cases you are
working on. For example, you can change `instance_type` (default is t2.small)
in `aws.tf` to large size if the bastion would require a high workload.

### Production Considerations

When considering production availability. We recommend [a region with three availability zones][az]
for best HA results.  Vault requires at least three zones.  Please feel free to
list any other software that requires more than two zones for HA.

### Build Resources

As a quick pre-flight check, run `make manifest` to compile your Terraform plan
and suss out any issues with naming, missing variables, configuration, etc.:

```
$ make manifest
terraform get -update
terraform plan -var-file aws.tfvars -out aws.tfplan
Refreshing Terraform state prior to plan...

<snip>

Plan: 129 to add, 0 to change, 0 to destroy.
```

If everything worked out you should see a summary of the plan.  If this is the
first time you've done this, all of your changes should be additions.  The
numbers may differ from the above output, and that's okay.

Now, to pull the trigger, run `make deploy`:

```
$ make deploy
```

Terraform will connect to AWS, using your **Access Key ID** and **Secret Key ID**,
and spin up all the things it needs.  When it finishes, you should be left with
a bunch of subnets, configured network ACLs, security groups, routing tables,
a NAT instance (for public internet connectivity) and a bastion host.

If you run into issues before this point refer to our [troubleshooting][troubleshooting]
doc for help.

### Automate Build and Teardown

When working with development environments only, there are options built into
Terraform that will allow you to configure additional variables and then run a
script that will automatically create or destroy the base Terraform environment
for you (a NAT server and a bastion host).  This allows us to help reduce runtime
cost.

Setup the variables of what time (in military time) that you'd like the script's
time range to monitor.

```
startup = "9"
shutdown = "17"
```

With the `startup` and `shutdown` variables configured in the `aws.tfvars` file,
you can then return to the `CODEX_ROOT/terraform/aws` folder and run:

* `make aws-watch`
* `make aws-stopwatch`

The first starts the background process that will be checking if it's time to
begin the teardown.  The second will shutdown the background process.

(( insert_file bastion_intro.md ))

* In the AWS Console, go to Services > EC2.  In the dashboard each of the
**Resources** are listed.  Find the _Running Instances_ click on it and locate
the bastion.  The _Public IP_ is an attribute in the _Decription_ tab.

### Connect to Bastion

You'll use the **EC2 Key Pair** `*.pem` file that was stored from the
[Generate EC2 Key Pair](aws.md#generate-ec2-key-pair) step before as your credential
to connect.

In forming the SSH connection command, use the `-i` flag to give SSH the path to
the `IdentityFile`.  The default user on the bastion server is `ubuntu`.  This
will change in a little bit though when we create a new user, so don't get too
comfy.

```
$ ssh -i ~/.ssh/cf-deploy.pem ubuntu@52.43.51.197
```

Problems connecting?  [Verify your SSH fingerprint][verify_ssh] in the
troubleshooting doc.

(( insert_file bastion_setup.md ))

(( insert_file proto_intro.md ))

(( insert_file vault_init.md ))

(( insert_file proto_bosh_intro.md ))

#### Make Manifest

Let's head into the `proto/` environment directory and see if we
can create a manifest, or (a more likely case) we still have to
provide some critical information:

```
$ cd ~/ops/bosh-deployments/us-west-2/proto
$ make manifest
9 error(s) detected:
 - $.meta.aws.access_key: Please supply an AWS Access Key
 - $.meta.aws.azs.z1: What Availability Zone will BOSH be in?
 - $.meta.aws.region: What AWS region are you going to use?
 - $.meta.aws.secret_key: Please supply an AWS Secret Key
 - $.meta.aws.ssh_key_name: What is your full key name?
 - $.meta.aws.default_sgs: What Security Groups?
 - $.meta.aws.private_key: What is the local path to the Amazon Private Key for this deployment?
 - $.networks.default.subnets: Specify subnets for your BOSH vm's network
 - $.meta.shield_public_key: Specify the SSH public key from this environment's SHIELD daemon
Availability Zone will BOSH be in?


Failed to merge templates; bailing...
Makefile:22: recipe for target 'manifest' failed
make: *** [manifest] Error 5
```

Drat. Let's focus on the `$.meta` subtree, since that's where most parameters are defined in
Genesis templates:

```
- $.meta.aws.access_key: Please supply an AWS Access Key
- $.meta.aws.azs.z1: What Availability Zone will BOSH be in?
- $.meta.aws.region: What AWS region are you going to use?
- $.meta.aws.secret_key: Please supply an AWS Secret Key
```

This is easy enough to supply.  We'll put these properties in
`properties.yml`:

```
$ cat properties.yml
---
meta:
  aws:
    region: us-west-2
    azs:
      z1: (( concat meta.aws.region "a" ))
    access_key: (( vault "secret/us-west-2:access_key" ))
    secret_key: (( vault "secret/us-west-2:secret_key" ))
```

I use the `(( concat ... ))` operator to [DRY][DRY] up the
configuration.  This way, if we need to move the BOSH Director to
a different region (for whatever reason) we just change
`meta.aws.region` and the availability zone just tacks on "a".

(We use the "a" availability zone because that's where our subnet
is located.)

I also configured the AWS access and secret keys by pointing
Genesis to the Vault.  Let's go put those credentials in the
Vault:

```
$ safe set secret/us-west-2 access_key secret_key
access_key [hidden]:
access_key [confirm]:

secret_key [hidden]:
secret_key [confirm]:

```

Let's try that `make manifest` again.

```
$ make manifest`
5 error(s) detected:
 - $.meta.aws.default_sgs: What security groups should VMs be placed in, if none are specified in the deployment manifest?
 - $.meta.aws.private_key: What private key will be used for establishing the ssh_tunnel (bosh-init only)?
 - $.meta.aws.ssh_key_name: What AWS keypair should be used for the vcap user?
 - $.meta.shield_public_key: Specify the SSH public key from this environment's SHIELD daemon
 - $.networks.default.subnets: Specify subnets for your BOSH vm's network


Failed to merge templates; bailing...
Makefile:22: recipe for target 'manifest' failed
make: *** [manifest] Error 5
```

Better. Let's configure our `cloud_provider` for AWS, using our EC2 key pair.
We need copy our EC2 private key to bastion host and path to the key for
`private_key` entry in the following `properties.yml`.


On your local computer, you can copy to the clipboard with the `pbcopy` command
on a macOS machine:

```
cat ~/.ssh/cf-deploy.pem | pbcopy
<paste values to /path/to/the/ec2/key.pem>
```

Then add the following to the `properties.yml` file.

```
$ cat properties.yml
---
meta:
  aws:
    region: us-west-2
    azs:
      z1: (( concat meta.aws.region "a" ))
    access_key: (( vault "secret/us-west-2:access_key" ))
    secret_key: (( vault "secret/us-west-2:secret_key" ))
    private_key: /path/to/the/ec2/key.pem
    ssh_key_name: your-ec2-keypair-name
    default_sgs:
      - restricted
```

Once more, with feeling:

```
$ make manifest
2 error(s) detected:
 - $.networks.default.subnets: Specify subnets for your BOSH vm's network
 - $.meta.shield_public_key: Specify the SSH public key from this environment's SHIELD daemon


Failed to merge templates; bailing...
Makefile:22: recipe for target 'manifest' failed
make: *** [manifest] Error 5
```

Excellent.  We're down to two issues.

(( insert_file proto_bosh_shield_ssh_key.md ))

Now, we should have only a single error left when we `make
manifest`:

```
$ make manifest
1 error(s) detected:
 - $.networks.default.subnets: Specify subnets for your BOSH vm's network


Failed to merge templates; bailing...
Makefile:22: recipe for target 'manifest' failed
make: *** [manifest] Error 5
```

So it's down to networking.

Refer back to your [Network Plan][netplan], and find the `global-infra-0`
subnet for the proto-BOSH in the AWS Console.  If you're using the plan in this
repository, that would be `10.4.1.0/24`, and we're allocating
`10.4.1.0/28` to our BOSH Director.  Our `networking.yml` file,
then, should look like this:

```
$ cat networking.yml
---
networks:
  - name: default
    subnets:
      - range:    10.4.1.0/24
        gateway:  10.4.1.1
        dns:     [10.4.0.2]
        cloud_properties:
          subnet: subnet-xxxxxxxx # <-- your AWS Subnet ID
          security_groups: [wide-open]
        reserved:
          - 10.4.1.2 - 10.4.1.3    # Amazon reserves these
            # proto-BOSH is in 10.4.1.0/28
          - 10.4.1.16 - 10.4.1.254 # Allocated to other deployments
        static:
          - 10.4.1.4
```

Our range is that of the actual subnet we are in, `10.4.1.0/24`
(in reality, the `/28` allocation is merely a tool of bookkeeping
that simplifies ACLs and firewall configuration).  As such, our
Amazon-provided default gateway is 10.4.1.1 (the first available
IP) and our DNS server is 10.4.0.2.

We identify our AWS-specific configuration under
`cloud_properties`, by calling out what AWS Subnet we want the EC2
instance to be placed in, and what EC2 Security Groups it should
be subject to.

Under the `reserved` block, we reserve the IPs that Amazon
reserves for its own use (see [Amazon's documentation][aws-subnets],
specifically the "Subnet sizing" section), and everything outside of
`10.4.1.0/28` (that is, `10.4.1.16` and above).

Finally, in `static` we reserve the first usable IP (`10.4.1.4`)
as static.  This will be assigned to our `bosh/0` director VM.

(( insert_file proto_bosh_deploy.md ))

(( insert_file proto_vault_intro.md ))

```
$ cd ~/ops/vault-deployments/us-west-2/proto
$ make manifest
10 error(s) detected:
 - $.compilation.cloud_properties.availability_zone: Define the z1 AWS availability zone
 - $.meta.aws.azs.z1: Define the z1 AWS availability zone
 - $.meta.aws.azs.z2: Define the z2 AWS availability zone
 - $.meta.aws.azs.z3: Define the z3 AWS availability zone
 - $.networks.vault_z1.subnets: Specify the z1 network for vault
 - $.networks.vault_z2.subnets: Specify the z2 network for vault
 - $.networks.vault_z3.subnets: Specify the z3 network for vault
 - $.resource_pools.small_z1.cloud_properties.availability_zone: Define the z1 AWS availability zone
 - $.resource_pools.small_z2.cloud_properties.availability_zone: Define the z2 AWS availability zone
 - $.resource_pools.small_z3.cloud_properties.availability_zone: Define the z3 AWS availability zone


Failed to merge templates; bailing...
Makefile:22: recipe for target 'manifest' failed
make: *** [manifest] Error 5
```

Vault is pretty self-contained, and doesn't have any secrets of
its own.  All you have to supply is your network configuration,
and any IaaS settings.

Referring back to our [Network Plan][netplan] again, we
find that Vault should be striped across three zone-isolated
networks:

  - **10.4.1.16/28** in zone 1 (a)
  - **10.4.2.16/28** in zone 2 (b)
  - **10.4.3.16/28** in zone 3 (c)

First, lets do our AWS-specific region/zone configuration, along with our Vault HA fully-qualified domain name:

```
$ cat properties.yml
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
```

Our `/28` ranges are actually in their corresponding `/24` ranges
because the `/28`'s are (again) just for bookkeeping and ACL
simplification.  That leaves us with this for our
`networking.yml`:

```
$ cat networking.yml
---
networks:
  - name: vault_z1
    subnets:
      - range:    10.4.1.0/24
        gateway:  10.4.1.1
        dns:     [10.4.0.2]
        cloud_properties:
          subnet: subnet-xxxxxxxx  # <--- your AWS Subnet ID
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
          subnet: subnet-yyyyyyyy  # <--- your AWS Subnet ID
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
          subnet: subnet-zzzzzzzz  # <--- your AWS Subnet ID
          security_groups: [wide-open]
        reserved:
          - 10.4.3.2 - 10.4.3.3    # Amazon reserves these
          - 10.4.3.4 - 10.4.3.15   # Allocated to other deployments
            # Vault (z3) is in 10.4.3.16/28
          - 10.4.3.32 - 10.4.3.254 # Allocated to other deployments
        static:
          - 10.4.3.16 - 10.4.3.18
```

That's a ton of configuration, but when you break it down it's not
all that bad.  We're defining three separate networks (one for
each of the three availability zones).  Each network has a unique
AWS Subnet ID, but they share the same EC2 Security Groups, since
we want uniform access control across the board.

The most difficult part of this configuration is getting the
reserved ranges and static ranges correct, and self-consistent
with the network range / gateway / DNS settings.  This is a bit
easier since our network plan allocates a different `/24` to each
zone network, meaning that only the third octet has to change from
zone to zone (x.x.1.x for zone 1, x.x.2.x for zone 2, etc.)

(( insert_file proto_vault_deploy.md ))

(( insert_file proto_vault_init.md ))

(( insert_file shield_intro.md ))

### Setting up AWS S3 For Backup Archives

To help keep things isolated, we're going to set up a brand new
IAM user just for backup archive storage.  It's a good idea to
name this user something like `backup` or `shield-backup` so that
no one tries to re-purpose it later, and so that it doesn't get
deleted. We also need to generate an access key for this user and store those credentials in the Vault:

```
$ safe set secret/us-west-2/proto/shield/aws access_key secret_key
access_key [hidden]:
access_key [confirm]:

secret_key [hidden]:
secret_key [confirm]:
```

You're also going to want to provision a dedicated S3 bucket to
store archives in, and name it something descriptive, like
`codex-backups`.

Since the generic S3 bucket policy is a little open (and we don't
want random people reading through our backups), we're going to
want to create our own policy. Go to the IAM user you just created, click
`permissions`, then click the blue button with `Create User Policy`, paste the
following policy and modify accordingly, click `Validate Policy` and apply the
policy afterwards.


```
{
  "Statement": [
    {
      "Effect"   : "Allow",
      "Action"   : "s3:ListAllMyBuckets",
      "Resource" : "arn:aws:iam:xxxxxxxxxxxx:user/zzzzz"
    },
    {
      "Effect"   : "Allow",
      "Action"   : "s3:*",
      "Resource" : [
        "arn:aws:s3:::your-bucket-name",
        "arn:aws:s3:::your-bucket-name/*"
      ]
    }
  ]
}
```

(( insert_file shield_setup.md ))

Next, we `make manifest` and see what we need to fill in.
```
$ make manifest
5 error(s) detected:
 - $.compilation.cloud_properties.availability_zone: What availability zone is SHIELD deployed to?
 - $.meta.az: What availability zone is SHIELD deployed to?
 - $.networks.shield.subnets: Specify your shield subnet
 - $.properties.shield.daemon.ssh_private_key: Specify the SSH private key that the daemon will use to talk to the agents
 - $.resource_pools.small.cloud_properties.availability_zone: What availability zone is SHIELD deployed to?


Failed to merge templates; bailing...
Makefile:22: recipe for target 'manifest' failed
make: *** [manifest] Error 5
```

By now, this should be old hat.  According to the [Network
Plan][netplan], the SHIELD deployment belongs in the
**10.4.1.32/28** network, in zone 1 (a).  Let's put that
information into `properties.yml`:

```
$ cat properties.yml
---
meta:
  az: us-west-2a
```

As we found with Vault, the `/28` range is actually in it's outer
`/24` range, since we're just using the `/28` subdivision for
convenience.

```
$ cat networking.yml
---
networks:
  - name: shield
    subnets:
      - range:    10.4.1.0/24
        gateway:  10.4.1.1
        dns:     [10.4.0.2]
        cloud_properties:
          subnet: subnet-xxxxxxxx  # <--- your AWS Subnet ID
          security_groups: [wide-open]
        reserved:
          - 10.4.1.2 - 10.4.1.3    # Amazon reserves these
          - 10.4.1.4 - 10.4.1.31   # Allocated to other deployments
            # SHIELD is in 10.4.1.32/28
          - 10.4.1.48 - 10.4.1.254 # Allocated to other deployments
        static:
          - 10.4.1.32 - 10.4.1.34
```

(Don't forget to change your `subnet` to match your AWS VPC
configuration.)

(( insert_file shield_deploy.md ))

(( insert_file bolo_intro.md ))

Now let's make manifest.

```
$ cd ~/ops/bolo-deployments/us-west-2/proto
$ make manifest

2 error(s) detected:
 - $.meta.az: What availability zone is Bolo deployed to?
 - $.networks.bolo.subnets: Specify your bolo subnet

Failed to merge templates; bailing...
Makefile:22: recipe for target 'manifest' failed
make: *** [manifest] Error 5
```

From the error message, we need to configure the following things for an AWS deployment of
bolo:

- Availability Zone (via `meta.az`)
- Networking configuration

According to the [Network Plan][netplan], the bolo deployment belongs in the
**10.4.1.64/28** network, in zone 1 (a). Let's configure the availability zone in `properties.yml`:

```
$ cat properties.yml
---
meta:
  region: us-west-2
  az: (( concat meta.region "a" ))
```

Since `10.4.1.64/28` is subdivision of the `10.4.1.0/24` subnet, we can configure networking as follows.

```
$ cat networking.yml
---
networks:
 - name: bolo
   type: manual
   subnets:
   - range: 10.4.1.0/24
     gateway: 10.4.1.1
     cloud_properties:
       subnet: subnet-xxxxxxxx #<--- your AWS Subnet ID
       security_groups: [wide-open]
     dns: [10.4.0.2]
     reserved:
       - 10.4.1.2   - 10.4.1.3  # Amazon reserves these
       - 10.4.1.4 - 10.4.1.63  # Allocated to other deployments
        # Bolo is in 10.4.1.64/28
       - 10.4.1.80 - 10.4.1.254 # Allocated to other deployments
     static:
       - 10.4.1.65 - 10.4.1.68
```

(( insert_file bolo_test.md ))

### Configuring Bolo Agents

Now that you have a Bolo installation, you're going to want to
configure your other deployments to use it.  To do that, you'll
need to add the `bolo` release to the deployment (if it isn't
already there), add the `dbolo` template to all the jobs you want
monitored, and configure `dbolo` to submit metrics to your
`bolo/0` VM in the bolo deployment.

**NOTE**: This may require configuration of network ACLs, security groups, etc.
If you experience issues with this step, you might want to start looking in
those areas first.

We will use shield as an example to show you how to configure Bolo Agents.

To add the release:

```
$ cd ~/ops/shield-deployments
$ genesis add release bolo latest
$ cd ~/ops/shield-deployments/us-west-2/proto
$ genesis use release bolo
```

If you do a `make refresh manifest` at this point, you should see a new
release being added to the top-level `releases` list.

To configure dbolo, you're going to want to add a line like the
last one here to all of your job template definitions:

```
jobs:
  - name: shield
    templates:
      - { release: bolo, name: dbolo }
```

Then, to configure `dbolo` to submit to your Bolo installation,
add the `dbolo.submission.address` property either globally or
per-job (strong recommendation for global, by the way).

If you have specific monitoring requirements, above and beyond
the stock host-health checks that the `linux` collector provides,
you can change per-job (or global) properties like the dbolo.collectors properties.

You can put those configuration in the `properties.yml` as follows:

```
properties:
  dbolo:
    submission:
      address: x.x.x.x # your Bolo VM IP
    collectors:
      - { every: 20s, run: 'linux' }
      - { every: 20s, run: 'httpd' }
      - { every: 20s, run: 'process -n nginx -m nginx' }
```

Remember that you will need to supply the `linux` collector
configuration, since Bolo skips the automatic `dbolo` settings you
get for free when you specify your own configuration.

### Further Reading on Bolo

More information can be found in the [Bolo BOSH Release README][bolo]
which contains a wealth of information about available graphs,
collectors, and deployment properties.

## Concourse

![Concourse][bastion_6]

### Deploying Concourse

If we're not already targeting the ops vault, do so now to save frustration later.

```
$ safe target proto
Now targeting proto at https://10.4.1.16:8200
```


From the `~/ops` folder let's generate a new `concourse` deployment, using the `--template` flag.

```
$ genesis new deployment --template concourse
```

Inside the `global` deployment level goes the site level definition.  For this concourse setup we'll use an `aws` template for an `us-west-2` site.

```
$ genesis new site --template aws us-west-2
Created site us-west-2 (from template aws):
~/ops/concourse-deployments/us-west-2
├── README
└── site
    ├── disk-pools.yml
    ├── jobs.yml
    ├── networks.yml
    ├── properties.yml
    ├── releases
    ├── resource-pools.yml
    ├── stemcell
    │   ├── name
    │   └── version
    └── update.yml

2 directories, 10 files
```

Finally now, because our vault is setup and targeted correctly we can generate our `environment` level configurations.  And begin the process of setting up the specific parameters for our environment.

```
$ cd ~/ops/concourse-deployments
$ genesis new env us-west-2 proto
Running env setup hook: ~/ops/concourse-deployments/.env_hooks/00_confirm_vault

(*) proto   https://10.4.1.16:8200
    init    http://127.0.0.1:8200

Use this Vault for storing deployment credentials?  [yes or no] yes
Running env setup hook: ~/ops/concourse-deployments/.env_hooks/gen_creds
Generating credentials for Concource CI
Created environment aws/proto:
~/ops/concourse-deployments/us-west-2/proto
├── cloudfoundry.yml
├── credentials.yml
├── director.yml
├── Makefile
├── monitoring.yml
├── name.yml
├── networking.yml
├── properties.yml
├── README
└── scaling.yml

```

Let's make the manifest:

```
$ cd ~/ops/concourse-deployments/us-west-2/proto
$ make manifest
11 error(s) detected:
 - $.compilation.cloud_properties.availability_zone: What availability zone should your concourse VMs be in?
 - $.jobs.haproxy.templates.haproxy.properties.ha_proxy.ssl_pem: Want ssl? define a pem
 - $.jobs.web.templates.atc.properties.external_url: What is the external URL for this concourse?
 - $.meta.availability_zone: What availability zone should your concourse VMs be in?
 - $.meta.external_url: What is the external URL for this concourse?
 - $.meta.ssl_pem: Want ssl? define a pem
 - $.networks.concourse.subnets: Specify your concourse subnet
 - $.resource_pools.db.cloud_properties.availability_zone: What availability zone should your concourse VMs be in?
 - $.resource_pools.haproxy.cloud_properties.availability_zone: What availability zone should your concourse VMs be in?
 - $.resource_pools.web.cloud_properties.availability_zone: What availability zone should your concourse VMs be in?
 - $.resource_pools.workers.cloud_properties.availability_zone: What availability zone should your concourse VMs be in?


Failed to merge templates; bailing...
Makefile:22: recipe for target 'manifest' failed
make: *** [manifest] Error 5
```

Again starting with Meta lines in `~/ops/concourse-deployments/us-west-2/proto`:

```
$ cat properties.yml
---
meta:
  availability_zone: "us-west-2a"   # Set this to match your first zone "aws_az1"
  external_url: "https://ci.x.x.x.x.sslip.io"  # Set as Elastic IP address of the bastion host to allow testing via SSH tunnel
  ssl_pem: ~
  #  ssl_pem: (( vault meta.vault_prefix "/web_ui:pem" ))
```

Be sure to replace the x.x.x.x in the external_url above with the Elastic IP address of the bastion host.

The `~` means we won't use SSL certs for now.  If you have proper certs or want to use self signed you can add them to vault under the `web_ui:pem` key

For networking, we put this inside `proto` environment level.

```
$ cat networking.yml
---
networks:
  - name: concourse
    subnets:
      - range: 10.4.1.0/24
        gateway: 10.4.1.1
        dns:     [10.4.1.2]
        static:
          - 10.4.1.48 - 10.4.1.56  # We use 48-64, reserving the first eight for static
        reserved:
          - 10.4.1.2 - 10.4.1.3    # Amazon reserves these
		  - 10.4.1.4 - 10.4.1.47   # Allocated to other deployments
          - 10.4.1.65 - 10.4.1.254 # Allocated to other deployments
        cloud_properties:
          subnet: subnet-nnnnnnnn # <-- your AWS Subnet ID
          security_groups: [wide-open]
```

After it is deployed, you can do a quick test by hitting the HAProxy machine

```
$ bosh vms us-west-2-proto-concourse
Acting as user 'admin' on deployment 'us-west-2-proto-concourse' on 'us-west-2-proto-bosh'

Director task 43

Task 43 done

+--------------------------------------------------+---------+-----+---------+------------+
| VM                                               | State   | AZ  | VM Type | IPs        |
+--------------------------------------------------+---------+-----+---------+------------+
| db/0 (fdb7a556-e285-4cf0-8f35-e103b96eff46)      | running | n/a | db      | 10.4.1.61  |
| haproxy/0 (5318df47-b138-44d7-b3a9-8a2a12833919) | running | n/a | haproxy | 10.4.1.51  |
| web/0 (ecb71ebc-421d-4caa-86af-81985958578b)     | running | n/a | web     | 10.4.1.48  |
| worker/0 (c2c081e0-c1ef-4c28-8c7d-ff589d05a1aa)  | running | n/a | workers | 10.4.1.62  |
| worker/1 (12a4ae1f-02fc-4c3b-846b-ae232215c77c)  | running | n/a | workers | 10.4.1.57  |
| worker/2 (b323f3ba-ebe4-4576-ab89-1bce3bc97e65)  | running | n/a | workers | 10.4.1.58  |
+--------------------------------------------------+---------+-----+---------+------------+

VMs total: 6
```

Smoke test HAProxy IP address:

```
$ curl -i 10.4.1.51
HTTP/1.1 200 OK
Date: Thu, 07 Jul 2016 04:50:05 GMT
Content-Type: text/html; charset=utf-8
Transfer-Encoding: chunked

<!DOCTYPE html>
<html lang="en">
  <head>
    <title>Concourse</title>
```

You can then run on a your local machine

```
$ ssh -L 8080:10.4.1.51:80 user@ci.x.x.x.x.sslip.io -i path_to_your_private_key
```

and hit http://localhost:8080 to get the Concourse UI. Be sure to replace `user`
with the `jumpbox` username on the bastion host and x.x.x.x with the IP address
of the bastion host.

### Setup Pipelines Using Concourse

TODO: Need an example to show how to setup pipeline for deployments using Concourse.

## Building out Sites and Environments

Now that the underlying infrastructure has been deployed, we can start deploying our alpha/beta/other sites, with Cloud Foundry, and any required services. When using Concourse to update BOSH deployments,
there are the concepts of `alpha` and `beta` sites. The alpha site is the initial place where all deployment changes are checked for sanity + deployability. Typically this is done with a `bosh-lite` VM. The `beta` sites are where site-level changes are vetted. Usually these are referred to as the sandbox or staging environments, and there will be one per site, by necessity. Once changes have passed both the alpha, and beta site, we know it is reasonable for them to be rolled out to other sites, like production.

### Alpha

#### BOSH-Lite

Since our `alpha` site will be a bosh lite running on AWS, we will need to deploy that to our [global infrastructure network][netplan].

First, lets make sure we're in the right place, targetting the right Vault:

```
$ cd ~/ops
$ safe target proto
Now targeting proto at https://10.4.1.16:8200
```

Now we can create our repo for deploying the bosh-lite:

```
$ genesis new deployment --template bosh-lite
cloning from template https://github.com/starkandwayne/bosh-lite-deployment
Cloning into '~/ops/bosh-lite-deployments'...
remote: Counting objects: 55, done.
remote: Compressing objects: 100% (33/33), done.
remote: Total 55 (delta 7), reused 55 (delta 7), pack-reused 0
Unpacking objects: 100% (55/55), done.
Checking connectivity... done.
Embedding genesis script into repository
genesis v1.5.2 (ec9c868f8e62)
[master 5421665] Initial clone of templated bosh-lite deployment
 3 files changed, 3672 insertions(+), 67 deletions(-)
  rewrite README.md (96%)
   create mode 100755 bin/genesis
```

Next lets create our site and environment:

```
$ cd bosh-lite-deployments
$ genesis new site --template aws us-west-2
Created site us-west-2 (from template aws):
~/ops/bosh-lite-deployments/us-west-2
├── README
└── site
    ├── disk-pools.yml
    ├── jobs.yml
    ├── networks.yml
    ├── properties.yml
    ├── README
    ├── releases
    ├── resource-pools.yml
    ├── stemcell
    │   ├── name
    │   └── version
    └── update.yml

2 directories, 11 files

$ genesis new env us-west-2 alpha
Running env setup hook: ~/ops/bosh-lite-deployments/.env_hooks/setup

(*) proto	https://10.4.1.16:8200

Use this Vault for storing deployment credentials?  [yes or no]yes
Setting up credentials in vault, under secret/us-west-2/alpha/bosh-lite
.
└── secret/us-west-2/alpha/bosh-lite
    ├── blobstore/


    │   ├── agent
    │   └── director
    ├── db
    ├── nats
    ├── users/
    │   ├── admin
    │   └── hm
    └── vcap




Created environment us-west-2/alpha:
~/ops/bosh-lite-deployments/us-west-2/alpha
├── cloudfoundry.yml
├── credentials.yml
├── director.yml
├── Makefile


├── monitoring.yml
├── name.yml
├── networking.yml
├── properties.yml
├── README
└── scaling.yml

0 directories, 10 files

```

Now lets try to deploy:

```
$ cd us-west-2/alpha/
$ make deploy
  checking https://genesis.starkandwayne.com for details on latest stemcell bosh-aws-xen-hvm-ubuntu-trusty-go_agent
  checking https://genesis.starkandwayne.com for details on release bosh/256.2
  checking https://genesis.starkandwayne.com for details on release bosh-warden-cpi/29
  checking https://genesis.starkandwayne.com for details on release garden-linux/0.339.0
  checking https://genesis.starkandwayne.com for details on release port-forwarding/2
8 error(s) detected:
 - $.meta.aws.azs.z1: What Availability Zone will BOSH be in?
 - $.meta.net.dns: What is the IP of the DNS server for this BOSH-Lite?
 - $.meta.net.gateway: What is the gateway of the network the BOSH-Lite will be on?
 - $.meta.net.range: What is the network address of the subnet BOSH-Lite will be on?
 - $.meta.net.reserved: Provide a list of reserved IP ranges for the subnet that BOSH-Lite will be on
 - $.meta.net.security_groups: What security groups should be applied to the BOSH-Lite?
 - $.meta.net.static: Provide a list of static IPs/ranges in the subnet that BOSH-Lite will choose from
 - $.meta.port_forwarding_rules: Define any port forwarding rules you wish to enable on the bosh-lite, or an empty array


Failed to merge templates; bailing...


Makefile:25: recipe for target 'deploy' failed
make: *** [deploy] Error 3
```

Looks like we only have a handful of parameters to update, all related to
networking, so lets fill out our `networking.yml`, after consulting the
[Network Plan][netplan] to find our global infrastructure network and the AWS
console to find our subnet ID:

```
$ cat networking.yml
---
meta:
  net:
    subnet: subnet-xxxxx # <--- your subnet ID here
    security_groups: [wide-open]
    range: 10.4.1.0/24
    gateway: 10.4.1.1
    dns: [10.4.0.2]
```

Since there are a bunch of other deployments on the infrastructure network, we should take care
to reserve the correct static + reserved IPs, so that we don't conflict with other deployments. Fortunately
that data can be referenced in the [Global Infrastructure IP Allocation section][infra-ips] of the Network Plan:

```
$ cat networking.yml
---
meta:
  net:
    subnet: subnet-xxxxx # <--- your subnet ID here
    security_groups: [wide-open]
    range: 10.4.1.0/24
    gateway: 10.4.1.1
    static: [10.4.1.80]
    reserved: [10.4.1.2 - 10.4.1.79, 10.4.1.96 - 10.4.1.255]
    dns: [10.4.0.2]
```

Lastly, we will need to add port-forwarding rules, so that things outside the bosh-lite can talk to its services.
Since we know we will be deploying Cloud Foundry, let's add rules for it:

```
$ cat properties.yml
---
meta:
  aws:
    azs:
      z1: us-west-2a
  port_forwarding_rules:
  - internal_ip: 10.244.0.34
    internal_port: 80
    external_port: 80
  - internal_ip: 10.244.0.34
    internal_port: 443
    external_port: 443
```

And finally, we can deploy again:

```
$ make deploy
  checking https://genesis.starkandwayne.com for details on stemcell bosh-aws-xen-hvm-ubuntu-trusty-go_agent/3262.2
    checking https://genesis.starkandwayne.com for details on release bosh/256.2
  checking https://genesis.starkandwayne.com for details on release bosh-warden-cpi/29
    checking https://genesis.starkandwayne.com for details on release garden-linux/0.339.0
  checking https://genesis.starkandwayne.com for details on release port-forwarding/2
    checking https://genesis.starkandwayne.com for details on stemcell bosh-aws-xen-hvm-ubuntu-trusty-go_agent/3262.2
  checking https://genesis.starkandwayne.com for details on release bosh/256.2
    checking https://genesis.starkandwayne.com for details on release bosh-warden-cpi/29
  checking https://genesis.starkandwayne.com for details on release garden-linux/0.339.0
    checking https://genesis.starkandwayne.com for details on release port-forwarding/2
Acting as user 'admin' on 'us-west-2-proto-bosh'
Checking whether release bosh/256.2 already exists...YES
Acting as user 'admin' on 'us-west-2-proto-bosh'
Checking whether release bosh-warden-cpi/29 already exists...YES
Acting as user 'admin' on 'us-west-2-proto-bosh'
Checking whether release garden-linux/0.339.0 already exists...YES
Acting as user 'admin' on 'us-west-2-proto-bosh'
Checking whether release port-forwarding/2 already exists...YES
Acting as user 'admin' on 'us-west-2-proto-bosh'
Checking if stemcell already exists...
Yes
Acting as user 'admin' on deployment 'us-west-2-alpha-bosh-lite' on 'us-west-2-proto-bosh'
Getting deployment properties from director...
Unable to get properties list from director, trying without it...

Detecting deployment changes
...
Deploying
---------
Are you sure you want to deploy? (type 'yes' to continue): yes

Director task 58
  Started preparing deployment > Preparing deployment. Done (00:00:00)
...
Task 58 done

Started		2016-07-14 19:14:31 UTC
Finished	2016-07-14 19:17:42 UTC
Duration	00:03:11

Deployed `us-west-2-alpha-bosh-lite' to `us-west-2-proto-bosh'
```

Now we can verify the deployment and set up our `bosh` CLI target:

```
# grab the admin password for the bosh-lite
$ safe get secret/us-west-2/alpha/bosh-lite/users/admin
--- # secret/us-west-2/alpha/bosh-lite/users/admin
password: YOUR-PASSWORD-WILL-BE-HERE


$ bosh target https://10.4.1.80:25555 alpha
Target set to `us-west-2-alpha-bosh-lite'
Your username: admin
Enter password:
Logged in as `admin'
$ bosh status
Config
             ~/.bosh_config

 Director
   Name       us-west-2-alpha-bosh-lite
     URL        https://10.4.1.80:25555
   Version    1.3232.2.0 (00000000)
     User       admin
   UUID       d0a12392-f1df-4394-99d1-2c6ce376f821
     CPI        vsphere_cpi
   dns        disabled
     compiled_package_cache disabled
   snapshots  disabled

   Deployment
     not set
```

Tadaaa! Time to commit all the changes to deployment repo, and push to where we're storing
them long-term.

#### Alpha Cloud Foundry

To deploy CF to our alpha environment, we will need to first ensure we're targeting the right
Vault/BOSH:

```
$ cd ~/ops
$ safe target proto

(*) proto	https://10.4.1.16:8200

$ bosh target alpha
Target set to `us-west-2-alpha-bosh-lite'
```

Now we'll create our deployment repo for cloudfoundry:

```
$ genesis new deployment --template cf
cloning from template https://github.com/starkandwayne/cf-deployment
Cloning into '~/ops/cf-deployments'...
remote: Counting objects: 268, done.
remote: Compressing objects: 100% (3/3), done.
remote: Total 268 (delta 0), reused 0 (delta 0), pack-reused 265
Receiving objects: 100% (268/268), 51.57 KiB | 0 bytes/s, done.
Resolving deltas: 100% (112/112), done.
Checking connectivity... done.
Embedding genesis script into repository
genesis v1.5.2 (ec9c868f8e62)
[master 1f0c534] Initial clone of templated cf deployment
 2 files changed, 3666 insertions(+), 150 deletions(-)
 rewrite README.md (99%)
 create mode 100755 bin/genesis
```

And generate our bosh-lite based alpha environment:

```
$ cd cf-deployments
$ genesis new site --template bosh-lite bosh-lite
Created site bosh-lite (from template bosh-lite):
~/ops/cf-deployments/bosh-lite
├── README
└── site
    ├── disk-pools.yml
    ├── jobs.yml
    ├── networks.yml
    ├── properties.yml
    ├── releases
    ├── resource-pools.yml
    ├── stemcell
    │   ├── name
    │   └── version
    └── update.yml

2 directories, 10 files

$ genesis new env bosh-lite alpha
Running env setup hook: ~/ops/cf-deployments/.env_hooks/00_confirm_vault

(*) proto	https://10.4.1.16:8200

Use this Vault for storing deployment credentials?  [yes or no] yes
Running env setup hook: ~/ops/cf-deployments/.env_hooks/setup_certs
Generating Cloud Foundry internal certs
Uploading Cloud Foundry internal certs to Vault
Running env setup hook: ~/ops/cf-deployments/.env_hooks/setup_cf_secrets
Creating JWT Signing Key
Creating app_ssh host key fingerprint
Generating secrets
Created environment bosh-lite/alpha:
~/ops/cf-deployments/bosh-lite/alpha
├── cloudfoundry.yml
├── credentials.yml
├── director.yml
├── Makefile
├── monitoring.yml
├── name.yml
├── networking.yml
├── properties.yml
├── README
└── scaling.yml

0 directories, 10 files


```

Unlike all the other deployments so far, we won't use `make manifest` to vet the manifest for CF. This is because the bosh-lite CF comes out of the box ready to deploy to a Vagrant-based bosh-lite with no tweaks.  Since we are using it as the Cloud Foundry for our alpha environment, we will need to customize the Cloud Foundry base domain, with a domain resolving to the IP of our `alpha` bosh-lite VM:

```
cd bosh-lite/alpha
$ cat properties.yml
---
meta:
  cf:
    base_domain: 10.4.1.80.sslip.io
```

Now we can deploy:

```
$ make deploy
  checking https://genesis.starkandwayne.com for details on release cf/237
  checking https://genesis.starkandwayne.com for details on release toolbelt/3.2.10
  checking https://genesis.starkandwayne.com for details on release postgres/1.0.3
  checking https://genesis.starkandwayne.com for details on release cf/237
  checking https://genesis.starkandwayne.com for details on release toolbelt/3.2.10
  checking https://genesis.starkandwayne.com for details on release postgres/1.0.3
Acting as user 'admin' on 'us-west-2-try-anything-bosh-lite'
Checking whether release cf/237 already exists...NO
Using remote release `https://bosh.io/d/github.com/cloudfoundry/cf-release?v=237'

Director task 1
  Started downloading remote release > Downloading remote release
...
Deploying
---------
Are you sure you want to deploy? (type 'yes' to continue): yes

Director task 12
  Started preparing deployment > Preparing deployment. Done (00:00:01)
...
Task 12 done

Started		2016-07-15 14:47:45 UTC
Finished	2016-07-15 14:51:28 UTC
Duration	00:03:43

Deployed `bosh-lite-alpha-cf' to `us-west-2-try-anything-bosh-lite'
```

And once complete, run the smoke tests for good measure:

```
$ genesis bosh run errand smoke_tests
Acting as user 'admin' on deployment 'bosh-lite-alpha-cf' on 'us-west-2-alpha-bosh-lite'

Director task 18
  Started preparing deployment > Preparing deployment. Done (00:00:02)

  Started preparing package compilation > Finding packages to compile. Done (00:00:01)

  Started creating missing vms > smoke_tests/0 (c609e4c5-29e7-4f66-81e1-b94b9139ee7d). Done (00:00:08)

  Started updating job smoke_tests > smoke_tests/0 (c609e4c5-29e7-4f66-81e1-b94b9139ee7d) (canary). Done (00:00:23)

  Started running errand > smoke_tests/0. Done (00:02:18)

  Started fetching logs for smoke_tests/c609e4c5-29e7-4f66-81e1-b94b9139ee7d (0) > Finding and packing log files. Done (00:00:01)

  Started deleting errand instances smoke_tests > smoke_tests/0 (c609e4c5-29e7-4f66-81e1-b94b9139ee7d). Done (00:00:03)

Task 18 done

Started         2016-10-05 14:15:16 UTC
Finished        2016-10-05 14:18:12 UTC
Duration        00:02:56

[stdout]
################################################################################################################
go version go1.6.3 linux/amd64
CONFIG=/var/vcap/jobs/smoke-tests/bin/config.json
...

Errand 'smoke_tests' completed successfully (exit code 0)
```

We now have our alpha-environment's Cloud Foundry stood up!

### First Beta Environment

Now that our `alpha` environment has been deployed, we can deploy our first beta environment to AWS. To do this, we will first deploy a BOSH Director for the environment using the `bosh-deployments` repo we generated back when we built our [proto-BOSH](#proto-bosh), and then deploy Cloud Foundry on top of it.

#### BOSH
```
$ cd ~/ops/bosh-deployments
$ bosh target proto-bosh
$ ls
us-west-2  bin  global  LICENSE  README.md
```

We already have the `us-west-2` site created, so now we will just need to create our new environment, and deploy it. Different names (sandbox or staging) for Beta have been used for different customers, here we call it staging.


```
$ safe target proto
Now targeting proto at http://10.10.10.6:8200
$ genesis new env us-west-2 staging
RSA 1024 bit CA certificates are loaded due to old openssl compatibility
Running env setup hook: ~/ops/bosh-deployments/.env_hooks/setup

 proto	http://10.10.10.6:8200

Use this Vault for storing deployment credentials?  [yes or no] yes
Setting up credentials in vault, under secret/us-west-2/staging/bosh
.
└── secret/us-west-2/staging/bosh
    ├── blobstore/
    │   ├── agent
    │   └── director
    ├── db
    ├── nats
    ├── users/
    │   ├── admin
    │   └── hm
    └── vcap


Created environment us-west-2/staging:
~/ops/bosh-deployments/us-west-2/staging
├── cloudfoundry.yml
├── credentials.yml
├── director.yml
├── Makefile
├── monitoring.yml
├── name.yml
├── networking.yml
├── properties.yml
├── README
└── scaling.yml

0 directories, 10 files

```

Notice, unlike the **proto-BOSH** setup, we do not specify `--type bosh-init`. This means we will use BOSH itself (in this case the **proto-BOSH**) to deploy our sandbox BOSH. Again, the environment hook created all of our credentials for us, but this time we targeted the long-term Vault, so there will be no need for migrating credentials around.

Let's try to deploy now, and see what information still needs to be resolved:

```
$ cd us-west-2/staging
$ make deploy
9 error(s) detected:
 - $.meta.aws.access_key: Please supply an AWS Access Key
 - $.meta.aws.azs.z1: What Availability Zone will BOSH be in?
 - $.meta.aws.default_sgs: What security groups should VMs be placed in, if none are specified in the deployment manifest?
 - $.meta.aws.private_key: What private key will be used for establishing the ssh_tunnel (bosh-init only)?
 - $.meta.aws.region: What AWS region are you going to use?
 - $.meta.aws.secret_key: Please supply an AWS Secret Key
 - $.meta.aws.ssh_key_name: What AWS keypair should be used for the vcap user?
 - $.meta.shield_public_key: Specify the SSH public key from this environment's SHIELD daemon
 - $.networks.default.subnets: Specify subnets for your BOSH vm's network


Failed to merge templates; bailing...
make: *** [deploy] Error 3
```

Looks like we need to provide the same type of data as we did for **proto-BOSH**. Lets fill in the basic properties:

```
$ cat > properties.yml <<EOF
---
meta:
  aws:
    region: us-west-2
    azs:
      z1: (( concat meta.aws.region "a" ))
    access_key: (( vault "secret/us-west-2:access_key" ))
    secret_key: (( vault "secret/us-west-2:secret_key" ))
    private_key: ~ # not needed, since not using bosh-lite
    ssh_key_name: your-ec2-keypair-name
    default_sgs: [wide-open]
  shield_public_key: (( vault "secret/us-west-2/proto/shield/keys/core:public" ))
EOF
```

This was a bit easier than it was for **proto-BOSH**, since our SHIELD public key exists now, and our
AWS keys are already in Vault.

Verifying our changes worked, we see that we only need to provide networking configuration at this point:

```
make deploy
$ make deploy
1 error(s) detected:
 - $.networks.default.subnets: Specify subnets for your BOSH vm's network


Failed to merge templates; bailing...
make: *** [deploy] Error 3

```

All that remains is filling in our networking details, so lets go consult our [Network Plan](https://github.com/starkandwayne/codex/blob/master/network.md). We will place the BOSH Director in the staging site's infrastructure network, in the first AZ we have defined (subnet name `staging-infra-0`, CIDR `10.4.32.0/24`). To do that, we'll need to update `networking.yml`:

```
$ cat > networking.yml <<EOF
---
networks:
  - name: default
    subnets:
      - range:    10.4.32.0/24
        gateway:  10.4.32.1
        dns:     [10.4.0.2]
        cloud_properties:
          subnet: subnet-xxxxxxxx # <-- the AWS Subnet ID for your staging-infra-0 network
          security_groups: [wide-open]
        reserved:
          - 10.4.32.2 - 10.4.32.3    # Amazon reserves these
            # BOSH is in 10.4.32.0/28
          - 10.4.32.16 - 10.4.32.254 # Allocated to other deployments
        static:
          - 10.4.32.4
EOF
```

Now that that's handled, let's deploy for real:

```
$ make deploy
$ make deploy
RSA 1024 bit CA certificates are loaded due to old openssl compatibility
Acting as user 'admin' on 'aws-proto-bosh-microboshen-aws'
Checking whether release bosh/256.2 already exists...YES
Acting as user 'admin' on 'aws-proto-bosh-microboshen-aws'
Checking whether release bosh-aws-cpi/53 already exists...YES
Acting as user 'admin' on 'aws-proto-bosh-microboshen-aws'
Checking whether release shield/6.2.1 already exists...YES
Acting as user 'admin' on 'aws-proto-bosh-microboshen-aws'
Checking if stemcell already exists...
Yes
Acting as user 'admin' on deployment 'us-west-2-staging-bosh' on 'aws-proto-bosh-microboshen-aws'
Getting deployment properties from director...

Detecting deployment changes
----------------------------
resource_pools:
- cloud_properties:
    availability_zone: us-east-1b
    ephemeral_disk:
      size: 25000
      type: gp2
    instance_type: m3.xlarge
  env:
    bosh:
      password: "<redacted>"
  name: bosh
  network: default
  stemcell:
    name: bosh-aws-xen-hvm-ubuntu-trusty-go_agent
    sha1: 971e869bd825eb0a7bee36a02fe2f61e930aaf29
    url: https://bosh.io/d/stemcells/bosh-aws-xen-hvm-ubuntu-trusty-go_agent?v=3232.6
...
Deploying
---------
Are you sure you want to deploy? (type 'yes' to continue): yes

Director task 144
  Started preparing deployment > Preparing deployment. Done (00:00:00)

  Started preparing package compilation > Finding packages to compile. Done (00:00:00)
...
Task 144 done

Started		2016-07-08 17:23:47 UTC
Finished	2016-07-08 17:34:46 UTC
Duration	00:10:59

Deployed 'us-west-2-staging-bosh' to 'us-west-2-proto-bosh'
```

This will take a little less time than **proto-BOSH** did (some packages were already compiled), and the next time you deploy, it go by much quicker, as all the packages should have been compiled by now (unless upgrading BOSH or the stemcell).

Once the deployment finishes, target the new BOSH Director to verify it works:

```
$ safe get secret/us-west-2/staging/bosh/users/admin # grab the admin user's password for bosh
$ bosh target https://10.4.32.4:25555 us-west-2-staging
Target set to 'us-west-2-staging-bosh'
Your username: admin
Enter password:
Logged in as 'admin'
```

Again, since our creds are already in the long-term vault, we can skip the credential migration that was done in the proto-bosh deployment and go straight to committing our new deployment to the repo, and pushing it upstream.

Now it's time to move on to deploying our `beta` (staging) Cloud Foundry!

#### Jumpboxen?

#### Beta Cloud Foundry

To deploy Cloud Foundry, we will go back into our `ops` directory, making use of
the `cf-deplyoments` repo created when we built our alpha site:

```
$ cd ~/ops/cf-deployments
```

Also, make sure that you're targeting the right Vault, for good measure:

```
$ safe target proto
```

We will now create an `us-west-2` site for CF:

```
$ genesis new site --template aws us-west-2
Created site us-west-2 (from template aws):
~/ops/cf-deployments/us-west-2
├── README
└── site
    ├── disk-pools.yml
    ├── jobs.yml
    ├── networks.yml
    ├── properties.yml
    ├── releases
    ├── resource-pools.yml
    ├── stemcell
    │   ├── name
    │   └── version
    └── update.yml

2 directories, 10 files

```

And the `staging` environment inside it:

```
$ genesis new env us-west-2 staging
RSA 1024 bit CA certificates are loaded due to old openssl compatibility
Running env setup hook: ~/ops/cf-deployments/.env_hooks/00_confirm_vault

 proto	http://10.10.10.6:8200

Use this Vault for storing deployment credentials?  [yes or no] yes
Running env setup hook: ~/ops/cf-deployments/.env_hooks/setup_certs
Generating Cloud Foundry internal certs
Uploading Cloud Foundry internal certs to Vault
Running env setup hook: ~/ops/cf-deployments/.env_hooks/setup_cf_secrets
Creating JWT Signing Key
Creating app_ssh host key fingerprint
Generating secrets
Created environment us-west-2/staging:
~/ops/cf-deployments/us-west-2/staging
├── cloudfoundry.yml
├── credentials.yml
├── director.yml
├── Makefile
├── monitoring.yml
├── name.yml
├── networking.yml
├── properties.yml
├── README
└── scaling.yml

0 directories, 10 files

```

As you might have guessed, the next step will be to see what parameters we need to fill in:

```
$ cd us-west-2/staging
$ make manifest
```

```
76 error(s) detected:
 - $.meta.azs.z1: What availability zone should the *_z1 vms be placed in?
 - $.meta.azs.z2: What availability zone should the *_z2 vms be placed in?
 - $.meta.azs.z3: What availability zone should the *_z3 vms be placed in?
 - $.meta.cf.base_domain: Enter the Cloud Foundry base domain
 - $.meta.cf.blobstore_config.fog_connection.aws_access_key_id: What is the access key id for the blobstore S3 buckets?
 - $.meta.cf.blobstore_config.fog_connection.aws_secret_access_key: What is the secret key for the blobstore S3 buckets?
 - $.meta.cf.blobstore_config.fog_connection.region: Which region are the blobstore S3 buckets in?
 - $.meta.cf.ccdb.host: What hostname/IP is the ccdb available at?
 - $.meta.cf.ccdb.pass: Specify the password of the ccdb user
 - $.meta.cf.ccdb.user: Specify the user to connect to the ccdb
 - $.meta.cf.diegodb.host: What hostname/IP is the diegodb available at?
 - $.meta.cf.diegodb.pass: Specify the password of the diegodb user
 - $.meta.cf.diegodb.user: Specify the user to connect to the diegodb
 - $.meta.cf.uaadb.host: What hostname/IP is the uaadb available at?
 - $.meta.cf.uaadb.pass: Specify the password of the uaadb user
 - $.meta.cf.uaadb.user: Specify the user to connect to the uaadb
 - $.meta.dns: Enter the DNS server for your VPC
 - $.meta.elbs: What elbs will be in front of the gorouters?
 - $.meta.router_security_groups: Enter the security groups which should be applied to the gorouter VMs
 - $.meta.security_groups: Enter the security groups which should be applied to CF VMs
 - $.meta.ssh_elbs: What elbs will be in front of the ssh-proxy (access_z*) nodes?
 - $.networks.cf1.subnets.0.cloud_properties.subnet: Enter the AWS subnet ID for this subnet
 - $.networks.cf1.subnets.0.gateway: Enter the Gateway for this subnet
 - $.networks.cf1.subnets.0.range: Enter the CIDR address for this subnet
 - $.networks.cf1.subnets.0.reserved: Enter the reserved IP ranges for this subnet
 - $.networks.cf1.subnets.0.static: Enter the static IP ranges for this subnet
 - $.networks.cf2.subnets.0.cloud_properties.subnet: Enter the AWS subnet ID for this subnet
 - $.networks.cf2.subnets.0.gateway: Enter the Gateway for this subnet
 - $.networks.cf2.subnets.0.range: Enter the CIDR address for this subnet
 - $.networks.cf2.subnets.0.reserved: Enter the reserved IP ranges for this subnet
 - $.networks.cf2.subnets.0.static: Enter the static IP ranges for this subnet
 - $.networks.cf3.subnets.0.cloud_properties.subnet: Enter the AWS subnet ID for this subnet
 - $.networks.cf3.subnets.0.gateway: Enter the Gateway for this subnet
 - $.networks.cf3.subnets.0.range: Enter the CIDR address for this subnet
 - $.networks.cf3.subnets.0.reserved: Enter the reserved IP ranges for this subnet
 - $.networks.cf3.subnets.0.static: Enter the static IP ranges for this subnet
 - $.networks.router1.subnets.0.cloud_properties.subnet: Enter the AWS subnet ID for this subnet
 - $.networks.router1.subnets.0.gateway: Enter the Gateway for this subnet
 - $.networks.router1.subnets.0.range: Enter the CIDR address for this subnet
 - $.networks.router1.subnets.0.reserved: Enter the reserved IP ranges for this subnet
 - $.networks.router1.subnets.0.static: Enter the static IP ranges for this subnet
 - $.networks.router2.subnets.0.cloud_properties.subnet: Enter the AWS subnet ID for this subnet
 - $.networks.router2.subnets.0.gateway: Enter the Gateway for this subnet
 - $.networks.router2.subnets.0.range: Enter the CIDR address for this subnet
 - $.networks.router2.subnets.0.reserved: Enter the reserved IP ranges for this subnet
 - $.networks.router2.subnets.0.static: Enter the static IP ranges for this subnet
 - $.networks.runner1.subnets.0.cloud_properties.subnet: Enter the AWS subnet ID for this subnet
 - $.networks.runner1.subnets.0.gateway: Enter the Gateway for this subnet
 - $.networks.runner1.subnets.0.range: Enter the CIDR address for this subnet
 - $.networks.runner1.subnets.0.reserved: Enter the reserved IP ranges for this subnet
 - $.networks.runner1.subnets.0.static: Enter the static IP ranges for this subnet
 - $.networks.runner2.subnets.0.cloud_properties.subnet: Enter the AWS subnet ID for this subnet
 - $.networks.runner2.subnets.0.gateway: Enter the Gateway for this subnet
 - $.networks.runner2.subnets.0.range: Enter the CIDR address for this subnet
 - $.networks.runner2.subnets.0.reserved: Enter the reserved IP ranges for this subnet
 - $.networks.runner2.subnets.0.static: Enter the static IP ranges for this subnet
 - $.networks.runner3.subnets.0.cloud_properties.subnet: Enter the AWS subnet ID for this subnet
 - $.networks.runner3.subnets.0.gateway: Enter the Gateway for this subnet
 - $.networks.runner3.subnets.0.range: Enter the CIDR address for this subnet
 - $.networks.runner3.subnets.0.reserved: Enter the reserved IP ranges for this subnet
 - $.networks.runner3.subnets.0.static: Enter the static IP ranges for this subnet
 - $.properties.cc.buildpacks.fog_connection.aws_access_key_id: What is the access key id for the blobstore S3 buckets?
 - $.properties.cc.buildpacks.fog_connection.aws_secret_access_key: What is the secret key for the blobstore S3 buckets?
 - $.properties.cc.buildpacks.fog_connection.region: Which region are the blobstore S3 buckets in?
 - $.properties.cc.droplets.fog_connection.aws_access_key_id: What is the access key id for the blobstore S3 buckets?
 - $.properties.cc.droplets.fog_connection.aws_secret_access_key: What is the secret key for the blobstore S3 buckets?
 - $.properties.cc.droplets.fog_connection.region: Which region are the blobstore S3 buckets in?
 - $.properties.cc.packages.fog_connection.aws_access_key_id: What is the access key id for the blobstore S3 buckets?
 - $.properties.cc.packages.fog_connection.aws_secret_access_key: What is the secret key for the blobstore S3 buckets?
 - $.properties.cc.packages.fog_connection.region: Which region are the blobstore S3 buckets in?
 - $.properties.cc.resource_pool.fog_connection.aws_access_key_id: What is the access key id for the blobstore S3 buckets?
 - $.properties.cc.resource_pool.fog_connection.aws_secret_access_key: What is the secret key for the blobstore S3 buckets?
 - $.properties.cc.resource_pool.fog_connection.region: Which region are the blobstore S3 buckets in?
 - $.properties.cc.security_group_definitions.load_balancer.rules: Specify the rules for allowing access for CF apps to talk to the CF Load Balancer External IPs
 - $.properties.cc.security_group_definitions.services.rules: Specify the rules for allowing access to CF services subnets
 - $.properties.cc.security_group_definitions.user_bosh_deployments.rules: Specify the rules for additional BOSH user services that apps will need to talk to


Failed to merge templates; bailing...
Makefile:22: recipe for target 'manifest' failed
make: *** [manifest] Error 5
```

Oh boy. That's a lot. Cloud Foundry must be complicated. Looks like a lot of the fog_connection properties are all duplicates though, so lets fill out `properties.yml` with those:

```
$ cat properties.yml
---
meta:
  skip_ssl_validation: true
  cf:
    blobstore_config:
      fog_connection:
        aws_access_key_id: (( vault "secret/us-west-2:access_key" ))
        aws_secret_access_key: (( vault "secret/us-west-2:secret_key" ))
        region: us-west-2
```

##### Setup RDS Database

Next, lets tackle the database situation. We will need to create RDS instances for the `uaadb` and `ccdb`, but first we need to generate a password for the RDS instances:

```
$ safe gen 40 secret/us-west-2/staging/cf/rds password
$ safe get secret/us-west-2/staging/cf/rds
--- # secret/us-west-2/staging/rds
password: pqzTtCTz7u32Z8nVlmvPotxHsSfTOvawRjnY7jTW
```

Now let's go back to the `terraform/aws` sub-directory of this repository and add to the `aws.tfvars` file the following configurations:

```
aws_rds_staging_enabled = "1"
aws_rds_staging_master_password = "<insert the generated RDS password>"
```

As a quick pre-flight check, run `make manifest` to compile your Terraform plan, a RDS Cluster and 3 RDS Instances should be created:

```
$ make manifest
terraform get -update
terraform plan -var-file aws.tfvars -out aws.tfplan
Refreshing Terraform state in-memory prior to plan...

...

Plan: 4 to add, 0 to change, 0 to destroy.
```

If everything worked out you, deploy the changes:

```
$ make deploy
```

**TODO:** Create the `ccdb`,`uaadb` and `diegodb` databases inside the RDS Instance.

We will manually create uaadb, ccdb and diegodb for now. First, connect to your PostgreSql database using the following command.

```
psql postgres://cfdbadmin:your_password@your_rds_instance_endpoint:5432/postgres
```

Then run `create database uaadb`, `create database ccdb` and `create database diegodb`. You also need to `create extension citext` on all of your databases.

Now that we have RDS instance and `ccdb`, `uaadb` and `diegodb` databases created inside it, lets refer to them in our `properties.yml` file:

```
cat properties.yml
---
meta:
  skip_ssl_validation: true
  cf:
    blobstore_config:
      fog_connection:
        aws_access_key_id: (( vault "secret/us-west-2:access_key" ))
        aws_secret_access_key: (( vault "secret/us-west-2:secret_key" ))
        region: us-east-1
    ccdb:
      host: "xxxxxx.rds.amazonaws.com" # <- your RDS Instance endpoint
      user: "cfdbadmin"
      pass: (( vault "secret/us-west-2/staging/cf/rds:password" ))
      scheme: postgres
      port: 5432
    uaadb:
      host: "xxxxxx.rds.amazonaws.com" # <- your RDS Instance endpoint
      user: "cfdbadmin"
      pass: (( vault "secret/us-west-2/staging/cf/rds:password" ))
      scheme: postgresql
      port: 5432
    diegodb:
      host: "xxxxxx.rds.amazonaws.com" # <- your RDS Instance endpoint
      user: "cfdbadmin"
      pass: (( vault "secret/us-west-2/staging/cf/rds:password" ))
      scheme: postgres
      port: 5432
properties:
  diego:
    bbs:
      sql:
        db_driver: postgres
        db_connection_string: (( concat "postgres://" meta.cf.diegodb.user ":" meta.cf.diegodb.pass "@" meta.cf.diegodb.host ":" meta.cf.diegodb.port "/" meta.cf.diegodb.dbname ))

```
We have to configure `db_driver` and `db_connection_string` for diego since the templates we use is MySQL and we are using PostgreSQL here.

Now it's time to create our Elastic Load Balancer that will be in front of the `gorouters`, but as we will need TLS termination we then need to create a SSL/TLS certificate for our domain.

Create first the CA Certificate:

```
$ mkdir -p /tmp/certs
$ cd /tmp/certs
$ certstrap init --common-name "CertAuth"
Enter passphrase (empty for no passphrase):

Enter same passphrase again:

Created out/CertAuth.key
Created out/CertAuth.crt
Created out/CertAuth.crl
```

Then create the certificates for your domain:

```
$ certstrap request-cert -common-name *.staging.<your domain> -domain *.system.staging.<your domain>,*.apps.staging.<your domain>,*.login.staging.<your domain>,*.uaa.staging.<your domain>

Enter passphrase (empty for no passphrase):

Enter same passphrase again:

Created out/*.staging.<your domain>.key
Created out/*.staging.<your domain>.csr
```

And last, sign the domain certificates with the CA certificate:

```
$ certstrap sign *.staging.<your domain> --CA CertAuth
Created out/*.staging.<your domain>.crt from out/*.staging.<your domain>.csr signed by out/CertAuth.key
```

For safety, let's store the certificates in Vault:

```
$ cd out
$ safe write secret/us-west-2/staging/cf/tls/ca "csr@CertAuth.crl"
$ safe write secret/us-west-2/staging/cf/tls/ca "crt@CertAuth.crt"
$ safe write secret/us-west-2/staging/cf/tls/ca "key@CertAuth.key"
$ safe write secret/us-west-2/staging/cf/tls/domain "crt@*.staging.<your domain>.crt"
$ safe write secret/us-west-2/staging/cf/tls/domain "csr@*.staging.<your domain>.csr"
$ safe write secret/us-west-2/staging/cf/tls/domain "key@*.staging.<your domain>.key"
```

Now let's go back to the `terraform/aws` sub-directory of this repository and add to the `aws.tfvars` file the following configurations:

```
aws_elb_staging_enabled = "1"
aws_elb_staging_cert_path = "/path/to/the/signed/domain/certificate.crt"
aws_elb_staging_private_key_path = "/path/to/the/domain/private.key"
```

As a quick pre-flight check, run `make manifest` to compile your Terraform plan. If everything worked out you, deploy the changes:

```
$ make deploy
```

From here we need to configure our domain to point to the ELB. Different clients may use different DNS servers. No matter which DNS server you are using, you will need add a CNAME record that maps the domain name to the ELB endpoint. In this project, we will set up a Route53 as the DNS server. You can log into the AWS Console, create a new _Hosted Zone_ for your domain. Then go back to the `terraform/aws` sub-directory of this repository and add to the `aws.tfvars` file the following configurations:

```
aws_route53_staging_enabled = "1"
aws_route53_staging_hosted_zone_id = "XXXXXXXXXXX"
```

As usual, run `make manifest` to compile your Terraform plan and if everything worked out you, deploy the changes:

```
$ make deploy
```

Lastly, let's make sure to add our Cloud Foundry domain to properties.yml:

```
---
meta:
  skip_ssl_validation: true
  cf:
    base_domain: staging.<your domain> # <- Your CF domain
    blobstore_config:
      fog_connection:
        aws_access_key_id: (( vault "secret/us-west-2:access_key" ))
        aws_secret_access_key: (( vault "secret/us-west-2:secret_key" ))
        region: us-east-1
    ccdb:
      host: "xxxxxx.rds.amazonaws.com" # <- your RDS Instance endpoint
      user: "cfdbadmin"
      pass: (( vault "secret/us-west-2/staging/cf/rds:password" ))
      scheme: postgres
      port: 5432
    uaadb:
      host: "xxxxxx.rds.amazonaws.com" # <- your RDS Instance endpoint
      user: "cfdbadmin"
      pass: (( vault "secret/us-west-2/staging/cf/rds:password" ))
      scheme: postgresql
      port: 5432
    diegodb:
      host: "xxxxxx.rds.amazonaws.com" # <- your RDS Instance endpoint
      user: "cfdbadmin"
      pass: (( vault "secret/us-west-2/staging/cf/rds:password" ))
      scheme: postgres
      port: 5432
```

And let's see what's left to fill out now:

```
$ make deploy
51 error(s) detected:
 - $.meta.azs.z1: What availability zone should the *_z1 vms be placed in?
 - $.meta.azs.z2: What availability zone should the *_z2 vms be placed in?
 - $.meta.azs.z3: What availability zone should the *_z3 vms be placed in?
 - $.meta.dns: Enter the DNS server for your VPC
 - $.meta.elbs: What elbs will be in front of the gorouters?
 - $.meta.router_security_groups: Enter the security groups which should be applied to the gorouter VMs
 - $.meta.security_groups: Enter the security groups which should be applied to CF VMs
 - $.meta.ssh_elbs: What elbs will be in front of the ssh-proxy (access_z*) nodes?
 - $.networks.cf1.subnets.0.cloud_properties.subnet: Enter the AWS subnet ID for this subnet
 - $.networks.cf1.subnets.0.gateway: Enter the Gateway for this subnet
 - $.networks.cf1.subnets.0.range: Enter the CIDR address for this subnet
 - $.networks.cf1.subnets.0.reserved: Enter the reserved IP ranges for this subnet
 - $.networks.cf1.subnets.0.static: Enter the static IP ranges for this subnet
 - $.networks.cf2.subnets.0.cloud_properties.subnet: Enter the AWS subnet ID for this subnet
 - $.networks.cf2.subnets.0.gateway: Enter the Gateway for this subnet
 - $.networks.cf2.subnets.0.range: Enter the CIDR address for this subnet
 - $.networks.cf2.subnets.0.reserved: Enter the reserved IP ranges for this subnet
 - $.networks.cf2.subnets.0.static: Enter the static IP ranges for this subnet
 - $.networks.cf3.subnets.0.cloud_properties.subnet: Enter the AWS subnet ID for this subnet
 - $.networks.cf3.subnets.0.gateway: Enter the Gateway for this subnet
 - $.networks.cf3.subnets.0.range: Enter the CIDR address for this subnet
 - $.networks.cf3.subnets.0.reserved: Enter the reserved IP ranges for this subnet
 - $.networks.cf3.subnets.0.static: Enter the static IP ranges for this subnet
 - $.networks.router1.subnets.0.cloud_properties.subnet: Enter the AWS subnet ID for this subnet
 - $.networks.router1.subnets.0.gateway: Enter the Gateway for this subnet
 - $.networks.router1.subnets.0.range: Enter the CIDR address for this subnet
 - $.networks.router1.subnets.0.reserved: Enter the reserved IP ranges for this subnet
 - $.networks.router1.subnets.0.static: Enter the static IP ranges for this subnet
 - $.networks.router2.subnets.0.cloud_properties.subnet: Enter the AWS subnet ID for this subnet
 - $.networks.router2.subnets.0.gateway: Enter the Gateway for this subnet
 - $.networks.router2.subnets.0.range: Enter the CIDR address for this subnet
 - $.networks.router2.subnets.0.reserved: Enter the reserved IP ranges for this subnet
 - $.networks.router2.subnets.0.static: Enter the static IP ranges for this subnet
 - $.networks.runner1.subnets.0.cloud_properties.subnet: Enter the AWS subnet ID for this subnet
 - $.networks.runner1.subnets.0.gateway: Enter the Gateway for this subnet
 - $.networks.runner1.subnets.0.range: Enter the CIDR address for this subnet
 - $.networks.runner1.subnets.0.reserved: Enter the reserved IP ranges for this subnet
 - $.networks.runner1.subnets.0.static: Enter the static IP ranges for this subnet
 - $.networks.runner2.subnets.0.cloud_properties.subnet: Enter the AWS subnet ID for this subnet
 - $.networks.runner2.subnets.0.gateway: Enter the Gateway for this subnet
 - $.networks.runner2.subnets.0.range: Enter the CIDR address for this subnet
 - $.networks.runner2.subnets.0.reserved: Enter the reserved IP ranges for this subnet
 - $.networks.runner2.subnets.0.static: Enter the static IP ranges for this subnet
 - $.networks.runner3.subnets.0.cloud_properties.subnet: Enter the AWS subnet ID for this subnet
 - $.networks.runner3.subnets.0.gateway: Enter the Gateway for this subnet
 - $.networks.runner3.subnets.0.range: Enter the CIDR address for this subnet
 - $.networks.runner3.subnets.0.reserved: Enter the reserved IP ranges for this subnet
 - $.networks.runner3.subnets.0.static: Enter the static IP ranges for this subnet
 - $.properties.cc.security_group_definitions.load_balancer.rules: Specify the rules for allowing access for CF apps to talk to the CF Load Balancer External IPs
 - $.properties.cc.security_group_definitions.services.rules: Specify the rules for allowing access to CF services subnets
 - $.properties.cc.security_group_definitions.user_bosh_deployments.rules: Specify the rules for additional BOSH user services that apps will need to talk to


Failed to merge templates; bailing...
Makefile:22: recipe for target 'manifest' failed
make: *** [manifest] Error 5
```

All of those parameters look like they're networking related. Time to start building out the `networking.yml` file. Since our VPC is `10.4.0.0/16`, Amazon will have provided a DNS server for us at `10.4.0.2`. We can grab the AZs and ELB names from our terraform output, and define our router + cf security groups, without consulting the Network Plan:

```
$ cat networking.yml
---
meta:
  azs:
    z1: us-west-2a
    z2: us-west-2b
    z3: us-west-2c
  dns: [10.4.0.2]
  elbs: [xxxxxx-staging-cf-elb] # <- ELB name
  ssh_elbs: [xxxxxx-staging-cf-ssh-elb] # <- SSH ELB name
  router_security_groups: [wide-open]
  security_groups: [wide-open]
```

Now, we can consult our [Network Plan][netplan] for the subnet information,  cross referencing with terraform output or the AWS console to get the subnet ID:

```
$ cat networking.yml
---
meta:
  azs:
    z1: us-west-2a
    z2: us-west-2b
    z3: us-west-2c
  dns: [10.4.0.2]
  elbs: [xxxxxx-staging-cf-elb] # <- ELB name
  ssh_elbs: [xxxxxx-staging-cf-ssh-elb] # <- SSH ELB name
  router_security_groups: [wide-open]
  security_groups: [wide-open]

networks:
- name: router1
  subnets:
  - range: 10.4.35.0/25
    static: [10.4.35.4 - 10.4.35.100]
    reserved: [10.4.35.2 - 10.4.35.3] # amazon reserves these
    gateway: 10.4.35.1
    cloud_properties:
      subnet: subnet-XXXXXX # <--- your subnet ID here
- name: router2
  subnets:
  - range: 10.4.35.128/25
    static: [10.4.35.132 - 10.4.35.227]
    reserved: [10.4.35.130 - 10.4.35.131] # amazon reserves these
    gateway: 10.4.35.129
    cloud_properties:
      subnet: subnet-XXXXXX # <--- your subnet ID here
- name: cf1
  subnets:
  - range: 10.4.36.0/24
    static: [10.4.36.4 - 10.4.36.100]
    reserved: [10.4.36.2 - 10.4.36.3] # amazon reserves these
    gateway: 10.4.36.1
    cloud_properties:
      subnet: subnet-XXXXXX # <--- your subnet ID here
- name: cf2
  subnets:
  - range: 10.4.37.0/24
    static: [10.4.37.4 - 10.4.37.100]
    reserved: [10.4.37.2 - 10.4.37.3] # amazon reserves these
    gateway: 10.4.37.1
    cloud_properties:
      subnet: subnet-XXXXXX # <--- your subnet ID here
- name: cf3
  subnets:
  - range: 10.4.38.0/24
    static: [10.4.38.4 - 10.4.38.100]
    reserved: [10.4.38.2 - 10.4.38.3] # amazon reserves these
    gateway: 10.4.38.1
    cloud_properties:
      subnet: subnet-XXXXXX # <--- your subnet ID here
- name: runner1
  subnets:
  - range: 10.4.39.0/24
    static: [10.4.39.4 - 10.4.39.100]
    reserved: [10.4.39.2 - 10.4.39.3] # amazon reserves these
    gateway: 10.4.39.1
    cloud_properties:
      subnet: subnet-XXXXXX # <--- your subnet ID here
- name: runner2
  subnets:
  - range: 10.4.40.0/24
    static: [10.4.40.4 - 10.4.40.100]
    reserved: [10.4.40.2 - 10.4.40.3] # amazon reserves these
    gateway: 10.4.40.1
    cloud_properties:
      subnet: subnet-XXXXXX # <--- your subnet ID here
- name: runner3
  subnets:
  - range: 10.4.41.0/24
    static: [10.4.41.4 - 10.4.41.100]
    reserved: [10.4.41.2 - 10.4.41.3] # amazon reserves these
    gateway: 10.4.41.1
    cloud_properties:
      subnet: subnet-XXXXXX # <--- your subnet ID here
```

Let's see what's left now:

```
$ make deploy
3 error(s) detected:
 - $.properties.cc.security_group_definitions.load_balancer.rules: Specify the rules for allowing access for CF apps to talk to the CF Load Balancer External IPs
 - $.properties.cc.security_group_definitions.services.rules: Specify the rules for allowing access to CF services subnets
 - $.properties.cc.security_group_definitions.user_bosh_deployments.rules: Specify the rules for additional BOSH user services that apps will need to talk to
```

The only bits left are the Cloud Foundry security group definitions (applied to each running app, not the SGs applied to the CF VMs). We add three sets of rules for apps to have access to by default - `load_balancer`, `services`, and `user_bosh_deployments`. The `load_balancer` group should have a rule allowing access to the public IP(s) of the Cloud Foundry installation, so that apps are able to talk to other apps. The `services` group should have rules allowing access to the internal IPs of the services networks (according to our [Network Plan][netplan], `10.4.42.0/24`, `10.4.43.0/24`, `10.4.44.0/24`). The `user_bosh_deployments` is used for any non-CF-services that the apps may need to talk to. In our case, there aren't any, so this can be an empty list.

```
$ cat networking.yml
---
meta:
  azs:
    z1: us-west-2a
    z2: us-west-2b
    z3: us-west-2c
  dns: [10.4.0.2]
  elbs: [xxxxxx-staging-cf-elb] # <- ELB name
  ssh_elbs: [xxxxxx-staging-cf-ssh-elb] # <- SSH ELB name
  router_security_group: [wide-open]
  security_groups: [wide-open]

networks:
- name: router1
  subnets:
  - range: 10.4.35.0/25
    static: [10.4.35.4 - 10.4.35.100]
    reserved: [10.4.35.2 - 10.4.35.3] # amazon reserves these
    gateway: 10.4.35.1
    cloud_properties:
      subnet: subnet-XXXXXX # <--- your subnet ID here
- name: router2
  subnets:
  - range: 10.4.35.128/25
    static: [10.4.35.132 - 10.4.35.227]
    reserved: [10.4.35.130 - 10.4.35.131] # amazon reserves these
    gateway: 10.4.35.129
    cloud_properties:
      subnet: subnet-XXXXXX # <--- your subnet ID here
- name: cf1
  subnets:
  - range: 10.4.36.0/24
    static: [10.4.36.4 - 10.4.36.100]
    reserved: [10.4.36.2 - 10.4.36.3] # amazon reserves these
    gateway: 10.4.36.1
    cloud_properties:
      subnet: subnet-XXXXXX # <--- your subnet ID here
- name: cf2
  subnets:
  - range: 10.4.37.0/24
    static: [10.4.37.4 - 10.4.37.100]
    reserved: [10.4.37.2 - 10.4.37.3] # amazon reserves these
    gateway: 10.4.37.1
    cloud_properties:
      subnet: subnet-XXXXXX # <--- your subnet ID here
- name: cf3
  subnets:
  - range: 10.4.38.0/24
    static: [10.4.38.4 - 10.4.38.100]
    reserved: [10.4.38.2 - 10.4.38.3] # amazon reserves these
    gateway: 10.4.38.1
    cloud_properties:
      subnet: subnet-XXXXXX # <--- your subnet ID here
- name: runner1
  subnets:
  - range: 10.4.39.0/24
    static: [10.4.39.4 - 10.4.39.100]
    reserved: [10.4.39.2 - 10.4.39.3] # amazon reserves these
    gateway: 10.4.39.1
    cloud_properties:
      subnet: subnet-XXXXXX # <--- your subnet ID here
- name: runner2
  subnets:
  - range: 10.4.40.0/24
    static: [10.4.40.4 - 10.4.40.100]
    reserved: [10.4.40.2 - 10.4.40.3] # amazon reserves these
    gateway: 10.4.40.1
    cloud_properties:
      subnet: subnet-XXXXXX # <--- your subnet ID here
- name: runner3
  subnets:
  - range: 10.4.41.0/24
    static: [10.4.41.4 - 10.4.41.100]
    reserved: [10.4.41.2 - 10.4.41.3] # amazon reserves these
    gateway: 10.4.41.1
    cloud_properties:
      subnet: subnet-XXXXXX # <--- your subnet ID here

properties:
  cc:
    security_group_definitions:
    - name: load_balancer
      rules: []
    - name: services
      rules:
      - destination: 10.4.42.0-10.4.44.255
        protocol: all
    - name: user_bosh_deployments
      rules: []
```
Another thing we may want to do is scaling the VM size to save some cost when we are deploying in non-production environment, for example, we can configure the `scaling.yml` as follows:

```
resource_pools:

- name: runner_z2
  cloud_properties:
    instance_type: t2.medium

- name: runner_z1
  cloud_properties:
    instance_type: t2.medium

- name: runner_z3
  cloud_properties:
    instance_type: t2.medium
```

That should be it, finally. Let's deploy!

```
$ make deploy
RSA 1024 bit CA certificates are loaded due to old openssl compatibility
Acting as user 'admin' on 'us-west-2-staging-bosh'
Checking whether release cf/237 already exists...NO
Using remote release 'https://bosh.io/d/github.com/cloudfoundry/cf-release?v=237'

Director task 6
  Started downloading remote release > Downloading remote release
...
Deploying
---------
Are you sure you want to deploy? (type 'yes' to continue): yes
...

Started		2016-07-08 17:23:47 UTC
Finished	2016-07-08 17:34:46 UTC
Duration	00:10:59

Deployed 'us-west-2-staging-cf' to 'us-west-2-staging-bosh'

```

You may encounter the following error when you are deploying Beta CF.

```
Unknown CPI error 'Unknown' with message 'Your quota allows for 0 more running instance(s). You requested at least 1.
```

Amazon has per-region limits for different types of resources. Check what resource type your failed job is using and request to increase limits for the resource your jobs are failing at. You can log into your Amazon console, go to EC2 services, on the left column click `Limits`, you can click the blue button says `Request limit increase` on the right of each type of resource. It takes less than 30 minutes get limits increase approved through Amazon.

If you want to scale your deployment in the current environment (here it is staging), you can modify `scaling.yml` in your `cf-deployments/us-west-2/staging` directory. In the following example, you scale runners in both AZ to 2. Afterwards you can run `make manifest` and `make deploy`, please always remember to verify your changes in the manifest before you type `yes` to deploy making sure the changes are what you want.

```
jobs:

- name: runner_z1
  instances: 2

- name: runner_z2
  instances: 2

```

After a long while of compiling and deploying VMs, your CF should now be up, and accessible! You can
check the sanity of the deployment via `genesis bosh run errand smoke_tests`. Target it using
`cf login -a https://api.system.<your CF domain>`. The admin user's password can be retrieved
from Vault. If you run into any trouble, make sure that your DNS is pointing properly to the
correct ELB for this environment, and that the ELB has the correct SSL certificate for your site.

##### Push An App to Beta Cloud Foundry

After you successfully deploy the Beta CF, you can push an simple app to learn more about CF. In the CF world, every application and service is scoped to a space. A space is inside an org and provides users with access to a shared location for application development, deployment, and maintenance. An org is a development account that an individual or multiple collaborators can own and use. You can click [orgs, spaces, roles and permissions][orgs and spaces] to learn more  details.

The first step is creating and org and an space and targeting the org and space you created by running the following commands.

```
cf create-org sw-codex
cf target -o sw-codex
cf create-space test
cf target -s test

```

Once you are in the space, you can push an very simple app [cf-env][cf-env]  to the CF. Clone the [cf-env][cf-env]  rego on your bastion server, then go inside the `cf-env` directory, simply run `cf push` and it will start to upload, stage and run your app.

Your `cf push` command may fail like this:

```
Using manifest file /home/user/cf-env/manifest.yml

Updating app cf-env in org sw-codex / space test as admin...
OK

Uploading cf-env...
FAILED
Error processing app files: Error uploading application.
Server error, status code: 500, error code: 10001, message: An unknown error occurred.

```
You can try to debug this yourself for a while or find the possible solution in [Debug Unknown Error When You Push Your APP to CF][DebugUnknownError].

### Production Environment

Deploying the production environment will be much like deploying the `beta` environment above. You will need to deploy a BOSH Director, Cloud Foundry, and any services also deployed in the `beta` site. Hostnames, credentials, network information, and possibly scaling parameters will all be different, but the procedure for deploying them is the same.

### Next Steps

Lather, rinse, repeat for all additional environments (dev, prod, loadtest, whatever's applicable to the client).

[//]: # (Links, please keep in alphabetical order)

[amazon-region-doc]: http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.RegionsAndAvailabilityZones.html
[aws]:               https://signin.aws.amazon.com/console
[aws-subnets]:       http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Subnets.html
[az]:                http://aws.amazon.com/about-aws/global-infrastructure/
[bastion_host]:      aws.md#bastion-host
[bolo]:              https://github.com/cloudfoundry-community/bolo-boshrelease
[cfconsul]:          https://docs.cloudfoundry.org/concepts/architecture/#bbs-consul
[cfetcd]:            https://docs.cloudfoundry.org/concepts/architecture/#etcd
[DRY]:               https://en.wikipedia.org/wiki/Don%27t_repeat_yourself
[genesis]:           https://github.com/starkandwayne/genesis
[jumpbox]:           https://github.com/starkandwayne/jumpbox
[netplan]:           https://github.com/starkandwayne/codex/blob/master/network.md
[ngrok-download]:    https://ngrok.com/download
[infra-ips]:         https://github.com/starkandwayne/codex/blob/master/part3/network.md#global-infrastructure-ip-allocation
[setup_credentials]: aws.md#setup-credentials
[spruce-129]:        https://github.com/geofffranks/spruce/issues/129
[slither]:           http://slither.io
[troubleshooting]:   troubleshooting.md
[use_terraform]:     aws.md#use-terraform
[verify_ssh]:        https://github.com/starkandwayne/codex/blob/master/troubleshooting.md#verify-keypair
[cf-env]:            https://github.com/cloudfoundry-community/cf-env
[orgs and spaces]:   https://docs.cloudfoundry.org/concepts/roles.html
[DebugUnknownError]: http://www.starkandwayne.com/blog/debug-unknown-error-when-you-push-your-app-to-cf/

[//]: # (Images, put in /images folder)

[levels_of_bosh]:         images/levels_of_bosh.png "Levels of Bosh"
[bastion_host_overview]:  images/bastion_host_overview.png "Bastion Host Overview"
[bastion_1]:              images/bastion_step_1.png "vault-init"
[bastion_2]:              images/bastion_step_2.png "proto-BOSH"
[bastion_3]:              images/bastion_step_3.png "Vault"
[bastion_4]:              images/bastion_step_4.png "Shield"
[bastion_5]:              images/bastion_step_5.png "Bolo"
[bastion_6]:              images/bastion_step_6.png "Concourse"
[global_network_diagram]: images/global_network_diagram.png "Global Network Diagram"
