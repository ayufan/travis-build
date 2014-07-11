module Travis
  module CLI
    class Run < RepoCommand
      description "executes a stage from the .travis.yml"
      on '-p', '--print', 'output stage instead of running it'
      on '-s', '--slug', 'slug to use (will try to detect from current git clone)'

      def setup
        error "run command is not available on #{RUBY_VERSION}" if RUBY_VERSION < '1.9.3'
        $:.unshift File.expand_path('../lib', __FILE__)
        require 'travis/build'
      end

      def run(*stages)
        puts(data.to_s)
        script = Travis::Build.script(data, logs: { build: true, state: false })
        if stages.empty?
          script = script.compile
        else
          stages.each do |stage|
            script.set('TRAVIS_STAGE', stage, :echo => false)
            script.run_stage(stage.to_sym)
          end
          script = script.sh.to_s
        end
        source = File.read(__FILE__).split("\n__END__\n", 2)[1] + script
        print? ? puts(source) : run_script(source, *stages)
      end

      private

        def run_script(source, *stages)
          script = File.expand_path(
            "~/.travis/.build/#{find_slug}/travis-build-" << stages.join('-')
          )
          FileUtils.mkdir_p(File.dirname(script))
          File.open(script, 'w') { |f| f.write(source) }
          FileUtils.chmod(0755, script)
          exec(script)
        end

        def data
          {
            :config => travis_config,
            repository: {
                source_url: `git config --get remote.origin.url`.strip!,
            slug: `basename "$PWD"`.strip!
          },
            build: {
                id: 1,
                number: 1
            },
            job: {
                id: 1,
                number: '0.0',
                branch: `git symbolic-ref --short HEAD`.strip!,
                commit: `git rev-parse HEAD`.strip!,
                pull_request: false
            }
          }
        end
    end
  end
end

__END__
#!/bin/bash

travis_result() { return; }

travis_assert() {
  local result=$?
  if [ $result -ne 0 ]; then
    echo -e "\n\033[33;1mThe command \"$TRAVIS_CMD\" failed and exited with $result during $TRAVIS_STAGE.\e[0m\n\nYour build has been stopped."
    travis_terminate 2
  fi
}

travis_terminate() {
  exit $1
}

travis_retry() {
  "$@"
  return $?
}

