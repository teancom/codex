### Deploying SHIELD

We'll start out with the Genesis template for SHIELD:

```
$ cd ~/ops
$ genesis new deployment --template shield
$ cd shield-deployments
```

Now we can set up our `(( insert_property site.name ))` site using the `(( insert_property template_name ))` template, with a
`proto` environment inside of it:

```
$ genesis new site --template (( insert_property template_name )) (( insert_property site.name ))
$ genesis new env (( insert_property site.name )) proto
$ cd (( insert_property site.name ))/proto
```
