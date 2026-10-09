require "ood_core/refinements/hash_extensions"
require "shellwords"

module OodCore
  module BatchConnect
    class Factory
      using Refinements::HashExtensions

      # Build the Selkies template from a configuration
      # @param config [#to_h] the configuration for the batch connect template
      def self.build_selkies(config)
        context = config.to_h.symbolize_keys.reject { |k, _| k == :template }
        Templates::Selkies.new(context)
      end
    end

    module Templates
      # A batch connect template that streams a desktop to the browser with
      # Selkies (https://github.com/selkies-project/selkies). The job runs
      # Selkies' session launcher, which starts what the node lacks (a sound
      # server, and an Xvfb on the X11 backend) and serves the desktop on the
      # port chosen here, so the portal's reverse proxy carries the page and
      # its WebSocket as it does for any web app.
      #
      # The app's main script is the desktop, as on the VNC templates, and the
      # session ends when it returns. Selkies runs in its secure mode: a master
      # token that never leaves the job provisions one session token, written
      # to the connection file as `password`, once Selkies answers and before
      # the session is reported running, so nobody else on the cluster network
      # reaches the port without it.
      class Selkies < Template
        # @param context [#to_h] the context used to render the template
        # @option context [#to_sym, Array<#to_sym>] :conn_params ([]) A list of
        #   connection parameters added to the connection file (`:host`,
        #   `:port` and `:password`, the session token, will always exist)
        # @option context [#to_s] :selkies_cmd ("selkies-session") the command
        #   that starts Selkies' session launcher: a native install or module
        #   (`selkies-session`), an AppImage (`/path/selkies.AppImage
        #   selkies-session`), or a container (`apptainer exec --nv
        #   /path/selkies.sif selkies-session`)
        # @option context [#to_s] :selkies_session a desktop installed on the
        #   node or in the container, by name (`xfce`, `kde`) or as a command,
        #   started in place of the app's script; empty starts the default
        #   desktop. Needed where the launcher cannot see the job's directory,
        #   as in a container with a home of its own. The session then runs
        #   until it is deleted or its walltime ends. Unset, the app's script
        #   is the desktop.
        # @option context [#to_s] :selkies_args ("") extra arguments passed to
        #   Selkies, such as `--wayland` for its Wayland backend
        # @option context [#to_s] :selkies_timeout_seconds
        #   ("${SELKIES_TIMEOUT_SECONDS:-120}") time in seconds to wait for
        #   Selkies to answer before the job fails
        # @option context [#to_i] :password_size (32) length of the session
        #   token and of the master token
        # @see Template
        def initialize(context = {})
          super
        end

        protected
          def password_size
            context.fetch(:password_size, 32).to_i
          end

        private
          # Pick the port and generate the tokens, and define how the launcher
          # starts. The master token reaches Selkies through the environment
          # alone, never a command line another user on the node can read; the
          # launcher is exec'd from the job's background subshell, so its PID
          # is the one the job waits on and the one the desktop signals.
          def before_script
            <<-EOT.gsub(/^ {14}/, "")
              # Pick Selkies' port and generate the session token the view carries
              port=$(find_port "${host}")
              [[ $? -eq 0 ]] || clean_up 1
              password=$(create_passwd "#{password_size}")

              # The master token that provisions it, passed on to containers
              # started with a clean environment as well
              SELKIES_MASTER_TOKEN=$(create_passwd "#{password_size}")
              export SELKIES_MASTER_TOKEN
              export APPTAINERENV_SELKIES_MASTER_TOKEN="${SELKIES_MASTER_TOKEN}"
              export SINGULARITYENV_SELKIES_MASTER_TOKEN="${SELKIES_MASTER_TOKEN}"

              # Selkies listens on every interface for the portal's proxy, which may
              # present the node's own address as the host, so the socket admits any
              # origin and the session token guards it instead
              selkies_launch () {
                local launcher_pid="${BASHPID}"
                local args=(#{launcher_args})
                # The app's script is the desktop, and the session ends when it returns;
                # a desktop the app names starts in the home, as a display manager starts one
                if [[ $# -gt 0 ]]; then
                  args+=(--session="bash -c $(printf '%q' "$1; kill -TERM ${launcher_pid}")")
                else
                  cd ~ || exit 1
                fi
                exec #{[selkies_cmd, '"${args[@]}"', selkies_args].reject(&:empty?).join(" ")}
              }

              #{super}
            EOT
          end

          # The launcher runs in place of the main script, which it starts as
          # the desktop unless the app names one
          def run_script
            script_desktop? ? "selkies_launch #{Shellwords.escape(super)}" : "selkies_launch"
          end

          # Provision the session token once Selkies answers, before OnDemand
          # reports the session running. Only a server holding the master
          # token accepts it, so a launcher that never received it ends the job
          # instead of serving the desktop without authentication.
          def after_script
            <<-EOT.gsub(/^ {14}/, "")
              #{super}

              # Wait for Selkies to answer, and give up if the launcher exits first; both
              # requests go to the node itself, never to a proxy the environment names
              echo "Waiting for Selkies on ${host}:${port}..."
              selkies_deadline=$((SECONDS + #{selkies_timeout_seconds}))
              until curl -fs -o /dev/null --noproxy '*' --max-time 2 "http://${host}:${port}/api/health"; do
                if ! kill -0 "${SCRIPT_PID}" 2>/dev/null || (( SECONDS >= selkies_deadline )); then
                  echo "Selkies did not answer on ${host}:${port}" >&2
                  clean_up 1
                fi
                sleep 1
              done

              # Provision the session token, with both tokens off the command line
              echo "Provisioning the session token..."
              curl -fsS -o /dev/null --max-time 10 --config - <<SELKIES_TOKENS || clean_up 1
              url = "http://${host}:${port}/api/tokens"
              noproxy = "*"
              header = "Authorization: Bearer ${SELKIES_MASTER_TOKEN}"
              header = "Content-Type: application/json"
              data = {"${password}":{"role":"controller","slot":1}}
              SELKIES_TOKENS
              echo "Selkies is ready on ${host}:${port}"
            EOT
          end

          # Stop the launcher before the job exits, so it stops Selkies before
          # the display and removes its runtime directory
          def clean_script
            <<-EOT.gsub(/^ {14}/, "")
              #{super}

              if [[ -n "${SCRIPT_PID}" ]] && kill -TERM "${SCRIPT_PID}" 2>/dev/null; then
                for ((i = 0; i < 40; i++)); do
                  kill -0 "${SCRIPT_PID}" 2>/dev/null || break
                  sleep 0.5
                done
              fi
            EOT
          end

          # Whether the app's main script is the desktop
          def script_desktop?
            !context.key?(:selkies_session)
          end

          # The launcher's arguments: a login and TLS are the portal's, and a
          # desktop the app names replaces its script
          def launcher_args
            session = context.fetch(:selkies_session, "").to_s
            args = ["--public", %(--port="${port}"), "--enable-basic-auth=false", "--enable-https=false", %(--allowed-origins='*')]
            args << "--session=#{Shellwords.escape(session)}" unless script_desktop? || session.empty?
            args.join(" ")
          end

          def selkies_cmd
            context.fetch(:selkies_cmd, "selkies-session").to_s
          end

          def selkies_args
            context.fetch(:selkies_args, "").to_s
          end

          def selkies_timeout_seconds
            context.fetch(:selkies_timeout_seconds, "${SELKIES_TIMEOUT_SECONDS:-120}").to_s
          end
      end
    end
  end
end
