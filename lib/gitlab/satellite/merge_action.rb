module Gitlab
  module Satellite
    # GitLab server-side merge
    class MergeAction < Action
      attr_accessor :merge_request

      def initialize(user, merge_request)
        super user, merge_request.target_project
        @merge_request = merge_request
      end

      # Checks if a merge request can be executed without user interaction
      def can_be_merged?
        project.satellite.log("can be merged")
        prepare_satellite!(project.satellite.repo)
        in_locked_and_timed_satellite do |merge_repo|
          project.satellite.log("starting merge in satellite")
          merge_in_satellite!(merge_repo)
        end

      end

      # Merges the source branch into the target branch in the satellite and
      # pushes it back to Gitolite.
      # It also removes the source branch if requested in the merge request.
      #
      # Returns false if the merge produced conflicts
      # Returns false if pushing from the satellite to Gitolite failed or was rejected
      # Returns true otherwise
      def merge!
        project.satellite.log("PID: #{project.id}: starting merge!")
        prepare_satellite!(project.satellite.repo)
        project.satellite.log("post prep satellite")
        in_locked_and_timed_satellite do |merge_repo|
          project.satellite.log("PID: #{project.id}: merge! in lock")

          if merge_in_satellite!(merge_repo)
            project.satellite.log("PID: #{project.id}: post satellite! ")
            # push merge back to Gitolite
            # will raise CommandFailed when push fails
            merge_repo.git.push({raise: true, timeout: true}, :origin, merge_request.target_branch)
            project.satellite.log("PID: #{project.id}: post push")
            # remove source branch
            if merge_request.should_remove_source_branch && !project.root_ref?(merge_request.source_branch)
              # will raise CommandFailed when push fails
              merge_repo.git.push({raise: true, timeout: true}, :origin, ":#{merge_request.source_branch}")
            end

            # merge, push and branch removal successful
            true
          end
        end
      rescue Grit::Git::CommandFailed => ex
        project.satellite.log("PID: #{project.id}: exception: #{ex.message}")
        ex.backtrace.each { |line| project.satellite.log(line) }
        Gitlab::GitLogger.error(ex.message)
        false
      end


      #Will do the diff of the source_branch into the target_branch
      def diff_in_satellite
        project.satellite.log("satellite diff")
        repo = project.satellite.repo
        prepare_satellite!(repo)
        in_locked_and_timed_satellite do |merge_repo|
          prepare_satellite_for_fork!(repo)
          project.satellite.log("PID: #{project.id}: starting satellite diff")

          if (merge_request.for_fork?)
            diff = repo.git.native(:diff, {timeout: 30, raise: true}, "origin/#{merge_request.target_branch}", "source/#{merge_request.source_branch}")
          else
            diff = repo.git.native(:diff, {timeout: 30, raise: true}, "#{merge_request.target_branch}", "#{merge_request.source_branch}")

          end

          #repo.remote({}, 'rm', 'source') unless remote.nil?
          project.satellite.log("PID: #{project.id}: diff: #{diff}")
          return diff

        end
      rescue Grit::Git::CommandFailed => ex
        Gitlab::GitLogger.error(ex.message)
        false
      end

      def format_patch
        project.satellite.log("satellite format_patch")
        repo = project.satellite.repo
        prepare_satellite!(repo)
        in_locked_and_timed_satellite do |merge_repo|
          prepare_satellite_for_fork!(repo)
          project.satellite.log("PID: #{project.id}: starting satellite format_patch")
          if (merge_request.for_fork?)
            patch = repo.git.format_patch({timeout: 30, raise: true, stdout: true}, "origin/#{merge_request.target_branch}", "source/#{merge_request.source_branch}")
          else
            patch = repo.git.format_patch({timeout: 30, raise: true, stdout: true}, "#{merge_request.target_branch}..#{merge_request.source_branch}")
          end
          #repo.remote({}, 'rm', 'source') unless remote.nil?
          project.satellite.log("PID: #{project.id}: diff: #{patch}")
          return patch

        end
      rescue Grit::Git::CommandFailed => ex
        Gitlab::GitLogger.error(ex.message)
        false
      end

      def commits_between_post_merge
        prepare_satellite!(repo)
        in_locked_and_timed_satellite do |merge_repo|
          project.satellite.log("PID: #{project.id}: starting post merge commits between")
          merge_in_satellite!(repo)
          project.satellite.log("PID: #{project.id}: finished merge for post merge commits between")
          # will raise CommandFailed when merge fails
          project.satellite.log("PID: #{project.id}: starting satellite commits between post merge")
          diff = repo.commits_between("origin/#{merge_request.target_branch}", "source/#{merge_request.source_branch}")

          #repo.remote({}, 'rm', 'source') unless remote.nil?
          project.satellite.log("PID: #{project.id}: diff: #{diff}")
          return diff

        end
      rescue Grit::Git::CommandFailed => ex
        Gitlab::GitLogger.error(ex.message)
        false
      end

      #Will do the diff of the source_branch into the target_branch
      def commits_between
        repo = project.satellite.repo
        prepare_satellite!(repo)
        in_locked_and_timed_satellite do |merge_repo|
          project.satellite.log("PID: #{project.id}: starting satellite commits between")

          prepare_satellite_for_fork!(repo)
          if (merge_request.for_fork?)
            diff = repo.commits_between("origin/#{merge_request.target_branch}", "source/#{merge_request.source_branch}")
          else
            diff = repo.commits_between("#{merge_request.target_branch}", "#{merge_request.source_branch}")
          end

          #repo.remote({}, 'rm', 'source') unless remote.nil?
          project.satellite.log("PID: #{project.id}: diff: #{diff}")
          return diff

        end
      rescue Grit::Git::CommandFailed => ex
        Gitlab::GitLogger.error(ex.message)
        false
      end

      private

      # Merges the source_branch into the target_branch in the satellite.
      #
      # Note: it will clear out the satellite before doing anything
      #
      # Returns false if the merge produced conflicts
      # Returns true otherwise
      def merge_in_satellite!(repo)
        project.satellite.log("PID: #{project.id}: prep merge")
        prepare_satellite_for_fork!(repo)

        # merge the source branch into the satellite
        # will raise CommandFailed when merge fails
        repo.git.pull({raise: true, timeout: true, no_ff: true}, 'source', merge_request.source_branch)
        project.satellite.log("PID: #{project.id}: pulled")

      rescue Grit::Git::CommandFailed => ex

        project.satellite.log("Command failed error #{ex.message}")
        ex.backtrace
        Gitlab::GitLogger.error(ex.message)
        false
      end

      # Assumes a satellite exists that is a fresh clone of the projects repo
      # adds remote at source to the satellite
      def prepare_satellite_for_fork!(repo)
        project.satellite.log("PID: #{project.id}: prep satellite for fork")
        # create target branch in satellite at the corresponding commit
        project.satellite.log("PID: #{project.id}: co target")
        repo.git.checkout({raise: true, timeout: true, b: true}, merge_request.target_branch, "origin/#{merge_request.target_branch}")
        project.satellite.log("PID: #{project.id}: add remote")
        repo.remote_add('source', @merge_request.source_project.repository.path_to_repo)
        project.satellite.log("PID: #{project.id}: remote successful")
        repo.remote_fetch('source')
      rescue Grit::Git::CommandFailed => ex
        project.satellite.log("Command failed error #{ex.message}")
        ex.backtrace
        Gitlab::GitLogger.error(ex.message)
        false
      end


    end
  end
end
