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

