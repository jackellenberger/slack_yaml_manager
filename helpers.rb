require 'yaml'
require 'slack-ruby-bot'

require 'pry'

module Helpers
  class << self
    def config
      # try to retrieve .config
      @config ||= begin
        config = YAML.load_file('.config')
        # save api token to env to satisfy slack-ruby-bot
        ENV["SLACK_API_TOKEN"] ||= config["slack_config"]["slack_api_token"]
        Slack.configure do |config|
          config.token = ENV["SLACK_API_TOKEN"]
        end
        config
      end
    end

    def client
      config
      @client ||= Slack::Web::Client.new
    end

    def channels
      @channels ||= client.channels_list.channels
    end

    def channel_to_id(name)
      channels.select { |hash| hash["name"] == name }.first["id"]
    end

    def users
      @users ||= client.users_list.members
    end

    def user_to_id(user)
      users.select { |hash| hash["name"] == user }.first["id"]
    end

    def id_to_user(id)
      if (/<@\w*>/).match(id)
        id = id[2..-2]
      end
      users.select { |hash| hash["id"] == id }.first["name"]
    end

    def cleanup_state(file, ext)
      # find all user backups, delete all but the most recent 2
      old_states_list = Dir.entries('.').select { |e| (/^#{file}-[0-9]*\.#{ext}$/).match(e) }.sort[0..-3]
      FileUtils.rm(old_states_list)
    end

    def save_state(file, ext, contents, backups=true)
      if backups && File.file?("#{file}.#{ext}")
        FileUtils.copy("#{file}.#{ext}", "#{file}-#{Time.now.to_i}.#{ext}")
      end
      File.open("#{file}.#{ext}",'w+') do |file|
        file.write contents.to_yaml
      end
      if backups
        cleanup_state(file, ext)
      end
    end

    def remove_mailto(str)
      return str unless !str.nil? && !str.empty? && str.start_with?('<mailto:') and str.end_with?('>')
      str[8..-2].split('|').last
    end

  end
end
