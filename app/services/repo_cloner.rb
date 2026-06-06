require 'open3'
require 'tmpdir'
require 'find'

class RepoCloner < ApplicationService
  class CloneError < StandardError; end

  MAX_GREP_RESULTS = 50
  MAX_FILE_BYTES   = 100_000

  def initialize(owner:, repo:, ref:, token:)
    @owner = owner
    @repo  = repo
    @ref   = ref
    @token = token
    @path  = nil
  end

  def self.with(owner:, repo:, ref:, token:)
    cloner = new(owner: owner, repo: repo, ref: ref, token: token)
    cloner.clone!
    yield cloner
  ensure
    cloner.cleanup
  end

  def clone!
    @path = Dir.mktmpdir('repo_clone_')
    url = "https://x-access-token:#{@token}@github.com/#{@owner}/#{@repo}.git"

    _out, err, status = Open3.capture3(
      'git', 'clone', '--depth=1', '--branch', @ref, url, @path
    )

    unless status.success?
      cleanup
      raise CloneError, "Clone failed for #{@owner}/#{@repo}@#{@ref}: #{sanitize(err)}"
    end

    Open3.capture3('git', '-C', @path, 'remote', 'remove', 'origin')
    purge_large_files

    log_info("RepoCloner: Cloned #{@owner}/#{@repo}@#{@ref} to temp dir")
    self
  end

  def get_file(path)
    full = File.join(@path, path)
    File.file?(full) ? File.read(full) : nil
  end

  def search(query)
    out, _err, status = Open3.capture3(
      'git', 'grep', '-I', '-rn', '--max-count=3', query,
      chdir: @path
    )

    return [] if status.exitstatus != 0

    out.lines.first(MAX_GREP_RESULTS).filter_map do |line|
      file, lineno, content = line.chomp.split(':', 3)
      next unless file && lineno && content

      { path: file, line: lineno.to_i, content: content.strip }
    end
  end

  def cleanup
    return unless @path

    FileUtils.rm_rf(@path)
    log_info("RepoCloner: Cleaned up temp clone for #{@owner}/#{@repo}")
    @path = nil
  end

  def cloned? = !@path.nil?

  private

  def purge_large_files
    Find.find(@path) do |path|
      Find.prune if File.basename(path) == '.git'
      File.delete(path) if File.file?(path) && File.size(path) > MAX_FILE_BYTES
    end
  end

  def sanitize(text)
    text.to_s.gsub(@token, '[TOKEN]')
  end
end
