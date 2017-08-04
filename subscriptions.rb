# Library to manage the reading of and writing to of users.yml
require 'yaml'
require 'fileutils'

class Hash
  def safe_invert
    self.each_with_object({}) { |(k,v),o| (o[v]||=[]) << k }
  end
end

module Subscriptions

  class << self
    def initialize
      # if data file doesn't exist, create it
      if !(File.file?('users.yml'))
        File.new('users.yml', 'w')
        # TODO: take snapshot of file w/ timestamp. if we have trouble reading the file, read from the snapshot
        @users = {}
      else
        @users = YAML.load_file('users.yml')
      end
    end # initialize

    # given a name, id, or email, retrun the name
    def find_user_key(str)
      str = str[1..-1] if str[0] == "@" # deal with @user
      str = str[2..-1] if (/<@\w*>/).match(str) # deal with @user that slack has garbled
      if @users.include?(str)
        return str
      else
        @users.each do |key, hash|
          return key if hash.values.include?(str)
        end
      end
      return nil
    end

    def add_user(name: nil, id: nil, email: nil)
      if @users.include?(name)
        return "Sorry, the user #{name} already exists!"
      end
      user_entry = {}
      user_entry["subscriptions"] = []
      user_entry["id"] = id
      user_entry["email"] = email
      @users[name] = user_entry
      Helpers.save_state('users','yml',@users)
      return "Added user \"#{name}\" with slack id \"#{id}\" and email \"#{email}\""
    end

    def delete_user(name: nil, id: nil, email: nil)
      if @users.include?(name)
        @users.delete(name)
        result = "User \"#{name}\" deleted"
      elsif id && target = @users.select{ |_,hash| hash["id"] == id }.keys.first
        @users.delete(target)
        result = "User \"#{id}\" deleted"
      elsif email && target = @users.select{ |_,hash| hash["email"] == email }.keys.first
        @users.delete(target)
        result = "User \"#{email}\" deleted"
      else
        return "User not found."
      end
      Helpers.save_state('users','yml',@users)
      return result
    end

    def list_users
      users_copy = Marshal.load(Marshal.dump(@users))
      users_copy.keys.each {|name| users_copy[name].delete("subscriptions") }
      users_copy
    end

    def add_subscription(user, path)
      if !@users.include?(user)
        return "Unable to find user \"#{user}\", have they been added?"
      end
      @users[user]["subscriptions"] ||= []
      @users[user]["subscriptions"] << path
      @users[user]["subscriptions"].uniq!
      Helpers.save_state('users','yml',@users)
      return "Added subscription to path \"#{path}\" for user \"#{user}\""
    end

    def delete_subscription(user, path)
      if !@users.include?(user)
        return "Unable to find user \"#{user}\", have they been added?"
      end

      if !@users[user]["subscriptions"].include?(path)
        return "Unable to find path \"#{path}\" for user \"#{user}.\n\"#{user}\" is currenty subscribed to the following paths:\n ```#{@users[user]["subscriptions"].to_yaml}```"
      end

      @users[user]["subscriptions"] -= [path]
      Helpers.save_state('users','yml',@users)
      return "Path \"#{path}\" deleted from \"#{user}\"'s subscriptions."
    end

    def delete_subscriptions(user)
      if !@users.include?(user)
        return "Unable to find user \"#{user}\", have they been added?"
      end

      @users[user]["subscriptions"] = []
      Helpers.save_state('users','yml',@users)
      return "\"#{user}\" has been unsubscribed from all paths."
    end

    def list_all_subscriptions
      users_copy = {}
      @users.each do |name, hash|
        users_copy[name] = hash["subscriptions"]
      end
      users_copy
    end

    def users_by_subscription
      list_all_subscriptions.safe_invert
    end
  end # class methods
end
