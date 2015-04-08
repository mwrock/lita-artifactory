module Lita
  module Handlers
    class Artifactory < Handler
      config :username, required: true
      config :password, required: true
      config :endpoint, required: true
      config :base_path, default: 'com/getchef'
      config :ssl_pem_file, default: nil
      config :ssl_verify, default: nil
      config :proxy_username, default: nil
      config :proxy_password, default: nil
      config :proxy_address, default: nil
      config :proxy_port, default: nil

      ARTIFACT = /[\w\-\.\+\_]+/
      VERSION = /[\w\-\.\+\_]+/
      FROM_REPO = /[\w\-]+/
      TO_REPO = /[\w\-]+/

      route /^artifact(?:ory)?\s+promote\s+#{ARTIFACT.source}\s+#{VERSION.source}\s+from\s+#{FROM_REPO.source}\s+to\s+#{TO_REPO.source}/i, :promote, command: true, help: {
        'artifactory promote' => 'promote <artifact> <version> from <from-repo> to <to-repo>'
      }

      route /^artifact(?:ory)?\s+repos(?:itories)?/i, :repos, command: true, help: {
        'artifactory repos' => 'list artifact repositories'
      }

      def promote(response)
        from_artifact = "#{repo_name(response.args[4])}/#{config.base_path}/#{response.args[1]}/#{response.args[2]}"
        to_artifact = "#{repo_name(response.args[6])}/#{config.base_path}/#{response.args[1]}/#{response.args[2]}"

        # Dry run first.
        dry = copy_folder("/api/copy/#{from_artifact}?to=#{to_artifact}&dry=1")

        if dry.include?('successfully') then
          real = copy_folder("/api/copy/#{from_artifact}?to=#{to_artifact}&dry=0")
          response.reply real
        else
          response.reply "ERROR: #{dry}"
        end
      end

      def repos(response)
        array = all_repos.collect { |repo| repo.key }
        response.reply "Artifact repositories:  #{array.join(', ')}"
      end

      private

      def client
        @client ||= ::Artifactory::Client.new(
          endpoint:       config.endpoint,
          username:       config.username,
          password:       config.password,
          ssl_pem_file:   config.ssl_pem_file,
          ssl_verify:     config.ssl_verify,
          proxy_username: config.proxy_username,
          proxy_password: config.proxy_password,
          proxy_address:  config.proxy_address,
          proxy_port:     config.proxy_port,
        )
      end

      def all_repos
        ::Artifactory::Resource::Repository.all(client: client)
      end

      # Using a raw request because the artifactory-client does not directly support copying a folder.
      # @TODO:  investigate raw requests further.  Params not working the way I (naively) thought they would.
      def copy_folder(uri)
        cmd = client.post(uri, fake: 'stuff')
        cmd['messages'][0]['message']
      end

      def repo_name(repo)
        tmp = repo
        tmp = 'omnibus-current-local' if tmp.eql?('local')
        tmp = 'omnibus-stable-local' if tmp.eql?('stable')
        tmp
      end
    end

    Lita.register_handler(Artifactory)
  end
end
