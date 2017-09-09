require 'http'
require 'json'
require 'yaml'
require 'slack-ruby-bot'

  require 'pry'

require_relative './helpers'
require_relative './subscriptions'
require_relative './repo_monitor'
SlackRubyBot::Client.logger.level = Logger::WARN

class MonitorBot < SlackRubyBot::Bot
  def self.initialize
    @config = Helpers.config
    @options = @config["slack_config"]["options"]
    Subscriptions.initialize
  end

  def self.run
    initialize
    super
  end

  def self.send_message(recipient, message)
    client = Slack::Web::Client.new
    @options["default_channel_id"] ||= Helpers.channel_to_id(@options["default_channel"])

    client.chat_postMessage(
      channel: @options["default_channel_id"],
      text: "@#{recipient}: #{message}",
      as_user: true
    )
  end

  def self.send_snippet(filename, content, initial_comment)
    client = Slack::Web::Client.new
    @options["default_channel_id"] ||= Helpers.channel_to_id(@options["default_channel"])

    client.files_upload(
      channels: @options["default_channel_id"],
      filename: filename,
      content: content,
      initial_comment: initial_comment
    )
  end

  # Intercepting Commands
  help do
    title 'Repo Monitor'
    desc 'A bot to help monitor changes happening to specific files across repositories'

    command 'hello' do
      desc 'replies yo what\'s up in the channel you @\'d them in'
    end

    command 'where do you live' do
      desc 'replies \'this is my home\' in the configured default repo'
    end
  end

  # Example "reply in the channel where addressed"
  command 'hello' do |client, data, match|
    client.say(
      channel: data.channel,
      text: "yo what's up"
    )
  end

  # Example "reply in specified channel"
  command 'where do you live?' do |client, data, match|
    @options["default_channel_id"] ||= Helpers.channel_to_id(@options["default_channel"], client)
    client.say(
      channel: @options["default_channel_id"] || data.channel,
      text: "this is my home"
    )
  end

  command 'spill your guts' do |client, data, match|
    begin
      file_text = File.read('users.yml')
    rescue
      file_text = "...error reading from users.yml"
    end
    client.say(
      channel: data.channel,
      text: "users.yml:\n ```#{file_text}```"
    )
  end

  ### Subscription Management
  # list_all_subscriptions
  command 'list subscriptions' do |client, data, match|
    client.say(
      channel: data.channel,
      text: "```#{Subscriptions.list_all_subscriptions.to_yaml}```"
    )
  end

  # list_users
  command 'list users' do |client, data, match|
    client.say(
      channel: data.channel,
      text: "```#{Subscriptions.list_users.to_yaml}```"
    )
  end

  #repo_monitor.run
  command 'any new changes?' do |client, data, match|
    client.say(
      channel: data.channel,
      text: "This is what I got. If you don't see anything, it's cause I got nothing."
    )
    RepoMonitor.run
  end

  # add_user
  match /[A|a]dd user[s]? (?<users>.+)+$/ do |client, data, match|
    # loop over comma seperated users
    users_array = match[:users].gsub('"','').split(',').map(&:strip)
    users_array.each do |user_string|
      # match words into slack id and email, then leave the remaining as the name
      user_array = user_string.split(' ')

      if id_match = user_array.find { |e| /^<@/ =~ e }
        id = Helpers.id_to_user(id)
      elsif id_match = user_array.find { |e| /^@/ =~ e }
        id = id_match[1..-1]
      end
      email_match = user_array.find { |e| /\w*@\w*\.\w*/ =~ e }
      email = Helpers.remove_mailto(email_match)
      name = (user_array - [id_match] - [email_match]).join(' ')
      if name.empty? || (id.nil? && email.nil?)
        result = "Please specify a name, and one or both of a slack username and email"
      else
        result = Subscriptions.add_user(name: name, id: id, email: email)
      end

      client.say(
        channel: data.channel,
        text: result
      )
    end
  end

  # delete_user
  match /([D|d]elete|[R|r]emove) user[s]? (?<users>.+)+$/ do |client, data, match|
    # loop over comma seperated users
    users_array = match[:users].gsub('"','').split(',').map(&:strip)
    users_array.each do |user_string|
      # match words into slack id and email, then leave the remaining as the name
      user_array = user_string.split(' ')

      if id_match = user_array.find { |e| /^<@/ =~ e }
        id = Helpers.id_to_user(id)
      elsif id_match = user_array.find { |e| /^@/ =~ e }
        id = id_match[1..-1]
      end
      email_match = user_array.find { |e| /\w*@\w*\.\w*/ =~ e }
      email = Helpers.remove_mailto(email_match)
      name = (user_array - [id_match] - [email]).join(' ')

      result = Subscriptions.delete_user(name: name, id: id, email: email)

      client.say(
        channel: data.channel,
        text: result
      )
    end
  end

  # add_subscription
  match /[S|s]ubscribe (?<users>.+)*\s?to (?<path>.+)+$/ do |client, data, match|
    binding.pry
    current_user = Helpers.id_to_user(data.user)
    if !match[:users]
      users_array = [current_user]
    else
      users_string = match[:users].gsub(/[M|m]e/, current_user)
      users_array = users_string.gsub('"','').split(',').map(&:strip)
    end
    users_array.each do |user_string|
      if !match[:path]
        result = "Please specify a path"
      else
        user = Subscriptions.find_user_key(user_string)
        result = Subscriptions.add_subscription(user, match[:path])
      end
      client.say(
        channel: data.channel,
        text: result
      )
    end
  end

  # delete_subscription
  match /([D|d]elete subscription to|[U|u]nsubscribe (?<users>.+)*\s?from) ((?!everything)(?<path>.+))+$/ do |client, data, match|
    current_user = Helpers.id_to_user(data.user)
    if !match[:users]
      users_array = [current_user]
    else
      users_string = match[:users].gsub(/[M|m]e/, current_user)
      users_array = match[:users].gsub('"','').split(',').map(&:strip)
    end
    users_array.each do |user_string|
      if !match[:path]
        result = "Please specify a path"
      else
        user = Subscriptions.find_user_key(user_string)
        result = Subscriptions.delete_subscription(user, match[:path])
      end
      client.say(
        channel: data.channel,
        text: result
      )
    end
  end

  match /[U|u]nsubscribe (?<users>.+)*\s?from everything[!]?$/ do |client, data, match|
    current_user = Helpers.id_to_user(data.user)
    if !match[:users]
      users_array = [current_user]
    else
      users_string = match[:users].gsub(/[M|m]e/, current_user)
      users_array = match[:users].gsub('"','').split(',').map(&:strip)
    end
    users_array.each do |user_string|
      user = Subscriptions.find_user_key(user_string)
      result = Subscriptions.delete_subscriptions(user)

      client.say(
        channel: data.channel,
        text: result
      )
    end

  end


end #class

# Runner
if __FILE__==$0
  MonitorBot.run
end
