module Shards
  module Factories
    def before_setup
      clear_repositories
      super
    end

    def create_path_repository(project, version = nil)
      Dir.mkdir_p(File.join(git_path(project), "src"))
      File.write(File.join(git_path(project), "src", "#{project}.cr"), "module #{project.capitalize}\nend")
      create_shard project, "name: #{project}\nversion: #{version}\n" if version
    end

    def create_git_repository(project, *versions)
      Dir.chdir(tmp_path) do
        run "git init #{project}"
      end

      Dir.mkdir(File.join(git_path(project), "src"))
      File.write(File.join(git_path(project), "src", "#{project}.cr"), "module #{project.capitalize}\nend")

      Dir.chdir(git_path(project)) do
        run "git add src/#{project}.cr"
      end

      versions.each { |version| create_git_release project, version }
    end

    def create_git_release(project, version, shard = true)
      Dir.chdir(git_path(project)) do
        if shard
          contents = if shard.is_a?(String)
                       shard
                     else
                       "name: #{project}\nversion: #{version}\n"
                     end
          create_shard project, contents
          run "git add shard.yml"
        end
        create_git_commit project, "release: v#{version}"
        run "git tag v#{version}"
      end
    end

    def create_git_commit(project, message = "new commit")
      Dir.chdir(git_path(project)) do
        run "git commit --allow-empty -m '#{message}'"
      end
    end

    def create_shard(project, contents)
      Dir.chdir(git_path(project)) do
        File.write "shard.yml", contents
      end
    end

    def clear_repositories
      run "rm -rf #{tmp_path}/*"
    end

    def git_commits(project)
      Dir.chdir(git_path(project)) do
        run("git log --format='%H'", capture: true).not_nil!.split("\n")
      end
    end

    def git_url(project)
      "file:///#{git_path(project)}"
    end

    def git_path(project)
      File.join(tmp_path, project.to_s)
    end

    def install_path(project, *path_names)
      File.join(tmp_path, "libs", project, *path_names)
    end

    def tmp_path
      @@tmp_path ||= begin
                       path = File.expand_path("../../tmp", __FILE__)
                       Dir.mkdir(path) unless Dir.exists?(path)
                       path
                     end
    end

    def run(command, capture = false)
      #puts command
      status = Process.run("/bin/sh", input: command, output: capture)

      if status.success?
        status.output
      else
        raise Exception.new("git command failed: #{command}")
      end
    end
  end
end

class Minitest::Test
  include Shards::Factories
end
