Prior to this commit the roster was stored in redis like this

    {"some-random-subscription-id-1" => {user_id: 1},
     "some-random-subscription-id-2" => {user_id: 2},
     "some-random-subscription-id-3" => {user_id: 2},
    }

This meant it works fine when one server generates all the subscription
UUID values, but that multiple nodes maintain completely isolated
in memory representations of the roster. This was hidden by the fact
that the
`get_roster` method call
https://github.com/stevegraham/slanger/blob/6bee2542a72271470adcea1d94aa9eb467e4cce3/lib/slanger/presence_channel.rb#L78
 was returning nil

So the subscriptions were a memoized in memory hash
 https://github.com/stevegraham/slanger/blob/6bee2542a72271470adcea1d94aa9eb467e4cce3/lib/slanger/presence_channel.rb#L107

We are now storing it like this where subscriptions hold details of the servers and the subscription_ids
    {user_1: subscriptions_1, user_2: subscriptions_2}

    or expanded:

    {
      user_1 => {
        "node:1" => ["subscription:random-subscription-id-1"],
        "node:2" => ["subscription:random-subscription-id-2"]
      },
      ...
    }


    fully expanded:

    {
      {"user_id" => "0f177369a3b71275d25ab1b44db9f95f",
       "user_info" => {}
      } => {
        "node:1" => ["subscription:random-subscription-id-1"],
        "node:2" => ["subscription:random-subscription-id-2"]
      },
      ...
    }


So that if a user is connected directly to multiple nodes, multiple times,
then we can keep representations of these in redis.

This way even if node 1 crashes, a janitor process can check for the status of the
various nodes using a health check and strip out the invalid subscriptions 
from redis and triggering member_removed messages if appropriate.


The janitor process
===================

Perform health check on each present-server redis array
* find all presence-channels
  * For each server x that doesn't respond
    * iterate over the values 
    * remove any keys matching "node:x"
    * for each value that becomes empty, send a member_removed message



