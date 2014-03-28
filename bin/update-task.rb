#!/bin/env ruby

# script to be run to check for updates to the git repository
# and compile new scores if needed

require 'log4r'
require 'rugged'

require_relative '../lib/eantifonar/config'

# path to the local git repository of the In adiutorium project
repo_path = '/home/igneus/tmp/In-adiutorium-working'

class GitUpdater

  def initialize(repo_path, logger)
    @repo_path = repo_path
    @logger = logger

    @new_content = false
    @updated_files = []
  end

  attr_reader :updated_files

  def pull
    repo = Rugged::Repository.new @repo_path
    last_head_ref = repo.head.target
    last_head_commit = repo.last_commit

    last_dir = Dir.pwd
    Dir.chdir @repo_path

    git_output = `git pull --force`
    @logger.debug('git pull: ' + git_output)

    Dir.chdir last_dir

    new_head_ref = repo.head.target
    new_head_commit = repo.last_commit
    if new_head_ref != last_head_ref then
      @new_content = true
    else
      # nothing changed
      return
    end

    # TODO: it may become quite adventurous here if it happens
    # that new head is not a descendant of the last one,
    # after a forced update. But for now we'll ignore such
    # a possibility.
    diff = repo.diff last_head_commit, new_head_commit
    @updated_files = diff.deltas.collect {|d| d.new_file[:path] }
    @updated_files.select! {|f| f =~ /\.ly$/ }
  end

  # has the last pull (if any) download any new content from github?
  def pulled_new_content?
    @new_content
  end
end

# copied from indexer; TODO: refactor
logger = Log4r::Logger.new 'indexing'
logger.outputters = [
  Log4r::StderrOutputter.new('stderr'),
  Log4r::FileOutputter.new('fo', :filename => EAntifonar::CONFIG.indexing_log)
]

logger.info 'Checking github for new content.'
git = GitUpdater.new repo_path, logger

git.pull
unless git.pulled_new_content?
  logger.info 'No new content found. Exiting.'
  exit 0
end

updated_files = git.updated_files
if updated_files.empty? then
  logger.info 'No files changed. Exiting.'
  exit 0
end

logger.info 'Proceeding to reindex files: ' + updated_files.inspect

# run indexer to reindex the updated files
system "bundle exec ruby bin/indexer.rb #{repo_path} #{updated_files.join(' ')}"
