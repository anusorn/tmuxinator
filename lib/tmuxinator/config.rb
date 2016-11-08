module Tmuxinator
  class Config
    LOCAL_DEFAULT = "./.tmuxinator.yml".freeze
    NO_LOCAL_FILE_MSG = "Project file at ./.tmuxinator.yml doesn't exist."

    class << self
      # The directory (created if needed) in which to store new projects
      def directory
        environment = ENV['TMUXINATOR_CONFIG']
        if !environment.nil? && !environment.empty?
          Dir.mkdir(environment) unless File.directory?(environment)
          return environment
        end
        return xdg if File.directory?(xdg)
        return home if File.directory?(home)
        # No project directory specified or existant, default to XDG:
        Dir.mkdir(xdg)
        xdg
      end

      def home
        ENV['HOME'] + "/.tmuxinator"
      end

      def xdg
        XDG['CONFIG'].to_s + "/tmuxinator"
      end

      def sample
        asset_path "sample.yml"
      end

      def default
        "#{directory}/default.yml"
      end

      def default?
        exists?("default")
      end

      def installed?
        Kernel.system("type tmux > /dev/null")
      end

      def version
        `tmux -V`.split(" ")[1].to_f if installed?
      end

      def default_path_option
        version && version < 1.8 ? "default-path" : "-c"
      end

      def editor?
        !ENV["EDITOR"].nil? && !ENV["EDITOR"].empty?
      end

      def shell?
        !ENV["SHELL"].nil? && !ENV["SHELL"].empty?
      end

      def exists?(name)
        File.exist?(project(name))
      end

      def local?
        local_project
      end

      # Pathname of given project searching only global directories
      def global_project(name)
        project_in(ENV['TMUXINATOR_CONFIG'], name) ||
        project_in(xdg, name) ||
        project_in(home, name)
      end

      def local_project
        [LOCAL_DEFAULT].detect { |f| File.exist?(f) }
      end

      def default_project(name)
        "#{directory}/#{name}.yml"
      end

      # Pathname of the given project
      def project(name)
        global_project(name) ||
        local_project ||
        default_project(name)
      end

      def template
        asset_path "template.erb"
      end

      def wemux_template
        asset_path "wemux_template.erb"
      end

      # Sorted list of all .yml files, including duplicates
      def configs
        configs = []
        directories.each do |directory|
          configs += Dir["#{directory}/**/*.yml"].collect do |path|
            path.gsub("#{directory}/", "").gsub(".yml", "")
          end
        end
        configs.sort
      end

      # Existant directories which may contain project files
      # Listed in search order
      # Used by `implode` and `list` commands
      def directories
        environment = ENV['TMUXINATOR_CONFIG']
        if !environment.nil? && !environment.empty?
          [environment]
        else
          [xdg, home].select { |d| File.directory? d }
        end
      end

      def validate(options = {})
        name = options[:name]
        options[:force_attach] ||= false
        options[:force_detach] ||= false

        project_file = if name.nil?
                         raise NO_LOCAL_FILE_MSG \
                           unless Tmuxinator::Config.local?
                         local_project
                       else
                         raise "Project #{name} doesn't exist." \
                           unless Tmuxinator::Config.exists?(name)
                         Tmuxinator::Config.project(name)
                       end
        Tmuxinator::Project.load(project_file, options).validate!
      end

      # Deprecated methods: ignore the 1st, use the 2nd
      alias :root             :directory
      alias :project_in_root  :global_project
      alias :project_in_local :local_project

      private

      def asset_path(asset)
        "#{File.dirname(__FILE__)}/assets/#{asset}"
      end

      # The first pathname of the project named 'name' found while
      # recursively searching 'directory'
      def project_in(directory, name)
        return nil if String(directory).empty?
        projects = Dir.glob("#{directory}/**/*.yml")
        projects.detect { |project| File.basename(project, ".yml") == name }
      end
    end
  end
end
