# KNIFE PLUGINS

This is my knife plugins directory.

## Grep
`knife grep` allows you to find hosts by specifying a partial hostname,
role, or IP address.

## Push Env, Edit Env, Set Rev
At Opscode, we always deploy from tags, which we set in data bag items
in the _environments_ data bag. Editing these is more work than it
should be, so imma make the computer do it. These things may or may not
be useful in your environment.

I have several Chef configurations layed out like this:

    TOPLEVEL
     | - ENVIRONMENT
          | - .chef/knife.rb
          ` - chef-repo
                | - cookbooks/
                | - data_bags
                |    ` - environments
                |         | - prod.json
                |         ` - preprod.json
                ` - roles/

The chef-repo contents are shared between all environments with
symlinks.

So, chances are your setup is different and these plugins will
not work out of the box for you. But maybe you will find them
interesting.

These plugins are also compatible with the following layout:

     | - ENVIRONMENT
          | - .chef/knife.rb
          | - cookbooks/
          | - data_bags
          |    ` - environments
          |         | - prod.json
          |         ` - preprod.json
          ` - roles/

## Deploy

The `knife deploy` plugin is essentially a wrapper for `knife ssh`,
but with a number of safety checks in place to help avoid mistakes due
to out of date cookbooks when deploying new code.  Knife deploy helps
you by:

- Making sure your local git repo is in sync with the remote repo
  (specified in knife.rb config, see below).

- Collecting the cookbooks used by the nodes you will be deploying to
  and comparing the cookbooks checksums on the server with those in
  your local cookbooks directory.  This helps avoid running a deploy
  when you have forgotten to upload modified cookbooks.

- After these checks are complete, you will get tmux, screen, or
  macterm sessions on the hosts matching your deploy query.

- Saves you typing.  The query you enter will be matched glob style
  against roles unless the query contains a ':', in which case it will
  be interpreted directly as a search query.

### configuration

In your knife.rb, add a stanza like this:

    deploy({
             "prod" => {
               :remote => "origin",
               :branch => "prod",
               :default_command => "screen"
             }
           })
