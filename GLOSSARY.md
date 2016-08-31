## [bolo](http://bolo.niftylogic.com/)

> bolo is a toolkit for building distributed, scalable monitoring systems. It provides a set of small, versatile components that you can plug together in new and exciting ways, to gather and aggregate metrics, mine data and track system states.

## [concourse](http://concourse.ci/)

> Concourse limits itself to three core concepts: tasks, resources, and the jobs that compose them. Interesting features like timed triggers and synchronizing usage of external environments are modeled in terms of these, rather than as layers on top.

Concourse is used to establish a continuous delivery pipeline.

## concourse runway stages

A naming convention for each subsequent stage of a concourse release pipeline is to use the first three letters of the greek alphabet.

  * alpha α
  * beta β
  * gamma γ

## [genesis](https://github.com/starkandwayne/genesis)

A tool to make managing multi-site BOSH deployments consistent and configurable.

## [jumpbox](https://github.com/starkandwayne/jumpbox)

Accessible from the internet, this server allows operators to gain access to servers behind network firewalls and DMZs.  Most specifically to help gain access to the BOSH Director in each environment to perform actions.

## proto-BOSH

A BOSH Director that sits before other site-level BOSH Directors (staging/production) in order to help enable more rapid updates to the site-level Directors.

## [safe](https://github.com/starkandwayne/safe)

A CLI interface for Vault.

## [shield](https://github.com/starkandwayne/shield)

Backup and restore for data systems.

## [spruce](https://github.com/geofffranks/spruce)

Template merge tool for BOSH YML files.

## [toolbelt](https://github.com/cloudfoundry-community/toolbelt-boshrelease)

> Toolbelt is an add-on BOSH release that provides a set of packages that are indispensable in troubleshooting and diagnosing issues on BOSH deployments.

## [vault](https://www.vaultproject.io/)

A tool that manages secrets.

## vault-init

A temporary Vault server used to store secrets during the creation of the `proto-BOSH` Director.  Once the `proto-BOSH` is complete, secrets are migrated to the Vault server in the `proto` environment.
