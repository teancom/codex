# Style Guide

To keep things consistent between documents here are some conventions we use.

## Commands

### Present then Provide

When you are about to teach a command for the first time, show the command with
it's options first, then explain the options.

If we were to teach how to use the `genesis new site` command, here's a good example.

```
genesis new site --template <name> <site_name>
```

The template `<name>` will be `aws` because that's our IaaS we're working with and
we recommend the `<site_name>` default to the AWS Region, ex. `us-west-2`.

```
$ genesis new site --template aws us-west-2
Created site us-west-2 (from template aws):
~/ops/bosh-deployments/aws
├── README
└── site
    ├── README
    ├── disk-pools.yml
    ├── jobs.yml
    ├── networks.yml
    ├── properties.yml
    ├── releases
    ├── resource-pools.yml
    ├── stemcell
    │   ├── name
    │   ├── sha1
    │   ├── url
    │   └── version
    └── update.yml

2 directories, 13 files

```

It's only recommended to do the presentation once, when introducing a new command,
you can simply use the command in context from that point on.

## Workspace

The workspace where operator files are kept is called `ops`.

```
$ mkdir -p ~/ops
$ cd ~/ops
```


## Typography

### Capitalization

When to capitalize and not?

If it's a proper noun, like The White House, it needs to be capitalized.  Welcome
to \`merica.

![merica][merica]

### Monospace

The names of software like `genesis`, `bosh-init`

### Bold

### Italic

### Note Commentary

The "**NOTE** this" commentary can be a useful tool to draw attention to the
reader that what's being said is important to remember, or adds additional
information.

Use bold and a colon to start the note.

**NOTE**: "I Love Lamp."  "Are you just saying that or do you really love the
lamp?" "**I Love Lamp.**"


[//]: # (Images, put in /images folder)

[merica]:     images/merica.jpg "'Merica Pew Pew"
