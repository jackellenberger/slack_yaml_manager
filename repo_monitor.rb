require 'git'

require_relative './helpers'
require_relative './subscriptions'
require_relative './slackbot'

class RepoMonitor

  def self.run
    monitor = RepoMonitor.new
    monitor.collect_changes
    monitor.notify_subscribers
  end

  def initialize
    @config = Helpers.config
    @options = @config["github_config"]["options"]

    # Git.configure do |config|
    #   config.binary_path = '/usr/bin/git'
    #   config.git_ssh = '/home/pair/.ssh/authorized_keys'
    # end

    Subscriptions.initialize

    @recipients = {}
    @git_instances = {}
  end

  def last_clone
    @last_clone ||= begin
      @config["github_config"]["last_clone"] || Time.now - 1.minute
    end
  end

  def git_clone(repo, url=nil)
    @git_instances[repo] ||= begin
      git_url = url || "#{@config["github_config"]["default_org_url"]}/#{repo}.git"
      begin
        if File.directory?("repos/#{repo}")
          git_instance = Git.open("repos/#{repo}")
          # prevent recloning too often
          if @config["github_config"]["last_clone"] > Time.now - 1.minute
            git_instance.pull
          end
        else
          git_instance = Git.clone(git_url, "repos/#{repo}", :log => Logger.new(STDOUT))
        end
      rescue Exception => e
        puts "Unable to create git instance for repo \"#{repo}\" at url \"#{git_url}\": #{e}"
        return nil
      end
      @config["github_config"]["last_clone"] = Time.now - 1.minute
      Helpers.save_state("","config", @config, false)

      # @git_instances[repo] = git_instance

      git_instance
    end
  end

  def git_diff(git, path)
    begin
      log = git.log.path(path).since(last_clone.to_s)

      if log.size > 0
        sha = log.last.sha
        diff = git.diff(sha).path(path).patch
        author_name = log.last.author.name
        author_email = log.last.author.email
        date = log.last.author.date
        return {:path=>path, :diff=>diff, :sha=>sha, :author_name=>author_name, :author_email=>author_email, :date=>date}
      end
    rescue
      error_msg = "Unable to get diff for path \"#{path}\" using git repo \"#{git.repo}\""
      puts error_msg

      return {:error=>error_msg, :git=>git, :path=>path}
    end
    return nil
  end

  def collect_changes()
    repo = @config["github_config"]["default_repo"]
    Subscriptions.users_by_subscription.each do |paths, subscriber|
      paths.each do |path|
        # check to see if we are looking at /path/to/subscription or repo:path/to/subscription
        if (repo_and_path = path.split(":")).length > 1
          repo = repo_and_path.first
          path = repo_and_path.last
        end
        #todo: url
        git_instance = @git_instances[repo] || git_clone(repo)

        if git_instance && diff_info = git_diff(git_instance, path)
          Subscriptions.users_by_subscription[paths].each do |subscriber|
            if @recipients[subscriber]
              @recipients[subscriber] << diff_info
            else
              @recipients[subscriber] = [diff_info]
            end
          end
        end
      end
    end
  end

  def notify_subscribers()
    MonitorBot.initialize
    @recipients.each do |subscriber, changes|
      bad_paths = changes.select { |h| h.key?(:error) }
      changes = changes - bad_paths
      changes.each do |change|
        MonitorBot.send_snippet(
          "Changes to #{change[:path]}",
          change[:diff],
          "Hey #{subscriber}, #{change[:author_name]}'s change on #{change[:date]} triggered your scription to #{change[:path]}. Sha: #{change[:sha]}."
        )
      end
      if bad_paths && !bad_paths.empty?
        error_message = "Bit of bad news, here. Some of your paths aren't working as intended. The paths #{bad_paths.map {|e| e[:path]}} don't seem to exist.\n"
        MonitorBot.send_message(subscriber, error_message)
      end
    end
  end

end #class

# Runner
if __FILE__==$0
  RepoMonitor.run
end
