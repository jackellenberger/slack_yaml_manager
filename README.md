# Slack Yaml Manager

Run controlled file operations on a yaml file through slack commands. A work in progress, built as a single use app to monitor and report on repository changes. I'll get around to fixing it, promise.

## Setup

After cloning this repository:

```
# create your config file
cp example.config .config
# Replace placeholder entries with your configuration.
# See [configuration](#Configuration) for more information.
vim .config

# acquire required dependencies
gem install bundler
bundle install

# start slackbot
rake
# or
ruby slackbot.rb

```

## Configuration

Below is an annotated example config, which will hopefully give some insight into setting up your own config.

```
slack_config: # required
  slack_api_token: example_token # this is a bot token. read more https://api.slack.com/bot-users
                                 # this will start with xoxb-*
  options:
    default_channel: "example" # set the default channel for this slackbot to post in.
                               # it will use this channel if there is no user specified channel
    as_user: true # set to true if you want a nice little picture of a monitor instead of a robot
github_config: # required for now, probably will change
  default_repo: "example" # if not otherwise specified by a user, the repo_monitor bot will
                          # check this repo for changes.
                          # a user can specify their own repo like by subscribing to
                          # <repo_name>:<path_in_repo>
bot_config: # debugging and logging options
  debug: true # why not debug mode, you know?
```

## Todo
* Break the the slack_yaml_manager slackbot away from the repo_monitor logic
  * Should i let users upload arbitrary ruby code through slack? seems like a bad idea.
  * Having multiple aribitrary scripts sitting in the slackbot's dir seems alright though.
* gemify it so you can easily attack the slackbot to existing ptrojects
