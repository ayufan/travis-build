require 'shellwords'

module Travis
  module Build
    class Script
      class ObjectiveC < Script
        DEFAULTS = {
          rvm:     'default',
          gemfile: 'Gemfile',
          podfile: 'Podfile',
        }

        include RVM
        include Bundler

        def use_directory_cache?
          super || data.cache?(:cocoapods)
        end

        def announce
          super
          cmd 'xcodebuild -version -sdk', fold: 'announce'
          uses_rubymotion? then: 'motion --version'
          podfile? then: 'pod --version'
        end

        def export
          super

          set 'TRAVIS_XCODE_SDK', xcode_sdk.shellescape, echo: false
          set 'TRAVIS_XCODE_VERSION', xcode_version.shellescape, echo: false if xcode_version?
          set 'TRAVIS_XCODE_SCHEME', config[:xcode_scheme].to_s.shellescape, echo: false
          set 'TRAVIS_XCODE_PROJECT', config[:xcode_project].to_s.shellescape, echo: false
          set 'TRAVIS_XCODE_WORKSPACE', config[:xcode_workspace].to_s.shellescape, echo: false
        end

        def setup
          super

          cmd "echo '#!/bin/bash\n# no-op' > /usr/local/bin/actool", echo: false
          cmd "chmod +x /usr/local/bin/actool", echo: false

          if xcode_version?
            fold("xcode-select") do |sh|
              xcode_installation_path = "/Applications/Xcode.app"
              xcode_installation_path_bak = "/Applications/Xcode.app.bak"
              xcode_version_installation_path = "/Applications/Xcode-#{xcode_version}.app"
              sh.if "-e #{xcode_installation_path}" do |shmv|
                shmv.cmd "sudo mv #{xcode_installation_path.shellescape} #{xcode_installation_path_bak.shellescape}"
              end
              sh.cmd "sudo ln -s #{xcode_version_installation_path.shellescape} #{xcode_installation_path.shellescape}"
            end
          end

          fold("start-simulator") do |sh|
            sh.echo "Starting iOS Simulator", ansi: :yellow
            sh.cmd "osascript -e 'set simpath to \"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Applications/iPhone Simulator.app/Contents/MacOS/iPhone Simulator\" as POSIX file' -e 'tell application \"Finder\"' -e 'open simpath' -e 'end tell'"
          end
        end

        def install
          super

          podfile? do |sh|
            # cache cocoapods if it has been enabled
            directory_cache.add(sh, "#{pod_dir}/Pods") if data.cache?(:cocoapods)

            sh.if "! ([[ -f #{pod_dir}/Podfile.lock && -f #{pod_dir}/Pods/Manifest.lock ]] && cmp --silent #{pod_dir}/Podfile.lock #{pod_dir}/Pods/Manifest.lock)", raw_condition: true do |pod_script|
              pod_script.fold("install.cocoapods") do |pod_fold|
                pod_fold.echo "Installing Pods with 'pod install'", ansi: :yellow
                pod_fold.cmd "pushd #{pod_dir}"
                pod_fold.cmd "pod install", retry: true
                pod_fold.cmd "popd"
              end
            end
          end
        end

        def script
          uses_rubymotion?(with_bundler: true, then: 'bundle exec rake spec')
          uses_rubymotion?(elif: true, then: 'rake spec')

          self.else do |script|
            if config[:xcode_scheme] && (config[:xcode_project] || config[:xcode_workspace])
              script.cmd "xctool #{xctool_args} build test"
            else
              script.cmd "echo -e \"\\033[33;1mWARNING:\\033[33m Using Objective-C testing without specifying a scheme and either a workspace or a project is deprecated.\"", echo: false
              script.cmd "echo \"  Check out our documentation for more information: http://about.travis-ci.org/docs/user/languages/objective-c/\"", echo: false
            end
          end
        end

        private

        def podfile?(*args, &block)
          self.if "-f #{config[:podfile].to_s.shellescape}", *args, &block
        end

        def pod_dir
          File.dirname(config[:podfile]).shellescape
        end

        def uses_rubymotion?(*args)
          conditional = '-f Rakefile && "$(cat Rakefile)" =~ require\ [\\"\\\']motion/project'
          conditional << ' && -f Gemfile' if args.first && args.first.is_a?(Hash) && args.first.delete(:with_bundler)

          if args.first && args.first.is_a?(Hash) && args.first.delete(:elif)
            self.elif conditional, *args
          else
            self.if conditional, *args
          end
        end

        def xctool_args
          config[:xctool_args].to_s.tap do |xctool_args|
            %w[project workspace scheme].each do |var|
              xctool_args << " -#{var} #{config[:"xcode_#{var}"].to_s.shellescape}" if config[:"xcode_#{var}"]
            end
            xctool_args << " -#{var} #{xcode_sdk}" if config[:xcode_sdk]
          end.strip
        end

        def xcode_version?
          config[:xcode_sdk].to_s =~ /-xcode/
        end

        def xcode_sdk
          config[:xcode_sdk].to_s.gsub(/^(.*)-xcode.+$/, '\1')
        end

        def xcode_version
          return 'default' unless xcode_version?
          config[:xcode_sdk].to_s.gsub(/^.*-xcode(.+)$/, '\1')
        end
      end
    end
  end
end
