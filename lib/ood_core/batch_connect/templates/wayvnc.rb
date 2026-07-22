require "ood_core/refinements/hash_extensions"

module OodCore
  module BatchConnect
    class Factory
      using Refinements::HashExtensions

      # Build the wayvnc template from a configuration
      # @param config [#to_h] the configuration for the batch connect template
      def self.build_wayvnc(config)
        context = config.to_h.symbolize_keys.reject { |k, _| k == :template }
        Templates::WayVNC.new(context)
      end
    end

    module Templates
      # A batch connect template that starts up a wayvnc server attached
      # to a wayland compositor launched by the app's main script. wayvnc
      # exposes its built-in websocket server directly on a port chosen by
      # this template (no websockify), so noVNC connects straight to it.
      class WayVNC < Template
        # @param context [#to_h] the context used to render the template
        # @option context [#to_sym, Array<#to_sym>] :conn_params ([]) A list of
        #   connection parameters added to the connection file. `:host`,
        #   `:port`, `:password` and `:websocket` will always exist. The
        #   websocket value mirrors `:port` since wayvnc serves the websocket
        #   on the same listener.
        # @option context [#to_s] :wayvnc_cmd ("wayvnc") path to the wayvnc
        #   executable
        # @option context [#to_s] :wayvnc_log ("wayvnc.log") path to the
        #   wayvnc log file (assumes you don't modify `:before_script`)
        # @option context [#to_s] :wayvnc_config ("wayvnc.conf") path to the
        #   wayvnc config file generated to enable password authentication
        #   (assumes you don't modify `:before_script`)
        # @option context [#to_s] :wayvnc_log_level ("warning") log level
        #   passed to wayvnc (`error`, `warning`, `info`, `debug`, `trace`,
        #   `quiet`)
        # @option context [#to_s] :wayland_socket
        #   ("${WAYLAND_DISPLAY:-wayland-0}") wayland socket name that
        #   wayvnc should attach to once the compositor creates it in
        #   XDG_RUNTIME_DIR
        # @option context [#to_s] :wayvnc_attach_timeout_seconds
        #   ("${WAYVNC_ATTACH_TIMEOUT_SECONDS:-30}") max time in seconds to
        #   wait for the wayland socket before failing the job
        # @option context [#to_s] :wayvnc_extra_args ("") any extra arguments
        #   passed to the wayvnc command
        # @see Template
        def initialize(context = {})
          super
        end

        private
          # We need to advertise the websocket port alongside the standard
          # host/port/password.
          def conn_params
            (super + [:websocket]).uniq
          end

          # Before running the main script, prepare the wayvnc config and
          # reserve the websocket port. wayvnc itself is started later from
          # `after_script` once the compositor has created its wayland socket.
          def before_script
            <<-EOT.gsub(/^ {14}/, "")
              # Generate the VNC password used by wayvnc clients
              echo "Setting VNC password..."
              password=$(create_passwd "#{password_size}")

              # Write a wayvnc config file that enables password auth
              echo "Writing wayvnc config..."
              (
                umask 077
                cat > "#{wayvnc_config}" <<WAYVNC_CONF
                enable_auth=true
                password=${password}
                relax_encryption=true
                allow_broken_crypto=true
              WAYVNC_CONF
              )

              # Find an available port for wayvnc to listen on. wayvnc serves
              # both VNC and the websocket on this same listener.
              websocket=$(find_port)
              export WAYVNC_WEBSOCKET_PORT="${websocket}"

              # XDG_RUNTIME_DIR should be a private directory since wlroots 
              # creates a permissive unix socket with no auth.
              #
              # On compute nodes there's typically no login session, so
              # /run/user/$(id -u) may not exist. Fall back to a private dir
              # under $TMPDIR if set, otherwise /tmp.
              if [[ -z "${XDG_RUNTIME_DIR}" || ! -d "${XDG_RUNTIME_DIR}" ]]; then
                if [[ -d "/run/user/$(id -u)" && -w "/run/user/$(id -u)" ]]; then
                  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
                else
                  export XDG_RUNTIME_DIR="${TMPDIR:-/tmp}/ood-runtime-$(id -u)"
                  mkdir -p "${XDG_RUNTIME_DIR}"
                  chmod 700 "${XDG_RUNTIME_DIR}"
                fi
              fi

              #{super}
            EOT
          end

          # After the main script has launched the compositor in the
          # background, wait for the wayland socket to appear and then
          # start wayvnc directly attached to it.
          def after_script
            <<-EOT.gsub(/^ {14}/, "")
              #{super}

              # Wait for the compositor socket before launching wayvnc.
              wayland_socket="#{wayland_socket}"
              attach_timeout="#{wayvnc_attach_timeout_seconds}"
              wayland_socket_path="${XDG_RUNTIME_DIR}/${wayland_socket}"

              echo "Waiting for wayland socket: ${wayland_socket_path} ..."
              ready=0
              for ((i=1; i<=attach_timeout*2; i++)); do
                if [[ -S "${wayland_socket_path}" ]]; then
                  ready=1
                  break
                fi
                sleep 0.5
              done

              if [[ ${ready} -ne 1 ]]; then
                echo "Timed out waiting ${attach_timeout}s for ${wayland_socket_path}" >&2
                clean_up 1
              fi

              echo "Starting wayvnc on ${host}:${WAYVNC_WEBSOCKET_PORT} attached to ${wayland_socket}..."
              WAYLAND_DISPLAY="${wayland_socket}" \\
              #{wayvnc_cmd} \\
                --config="#{wayvnc_config}" \\
                --log-level=#{wayvnc_log_level} \\
                #{wayvnc_extra_args} \\
                "ws:0.0.0.0:${WAYVNC_WEBSOCKET_PORT}" \\
                &> "#{wayvnc_log}" &
              WAYVNC_PID=$!

              # Make sure wayvnc actually started up and is listening.
              wait_until_port_used "localhost:${WAYVNC_WEBSOCKET_PORT}" 30
              if ! kill -0 ${WAYVNC_PID} 2>/dev/null; then
                echo "wayvnc failed to start; see #{wayvnc_log}" >&2
                clean_up 1
              fi

              echo "Successfully started wayvnc on ${host}:${WAYVNC_WEBSOCKET_PORT}..."
            EOT
          end

          # Clean up the wayvnc process
          def clean_script
            <<-EOT.gsub(/^ {14}/, "")
              #{super}
              [[ -n ${WAYVNC_PID} ]] && kill -TERM ${WAYVNC_PID} 2>/dev/null
            EOT
          end

          def wayvnc_cmd
            context.fetch(:wayvnc_cmd, "wayvnc").to_s
          end

          def wayvnc_log
            context.fetch(:wayvnc_log, "$PWD/wayvnc.log").to_s
          end

          def wayvnc_config
            context.fetch(:wayvnc_config, "$PWD/wayvnc.conf").to_s
          end

          def wayvnc_log_level
            context.fetch(:wayvnc_log_level, "warning").to_s
          end

          def wayvnc_extra_args
            context.fetch(:wayvnc_extra_args, "").to_s
          end

          def wayland_socket
            context.fetch(:wayland_socket, '${WAYLAND_DISPLAY:-wayland-0}').to_s
          end

          def wayvnc_attach_timeout_seconds
            context.fetch(:wayvnc_attach_timeout_seconds, '${WAYVNC_ATTACH_TIMEOUT_SECONDS:-30}').to_s
          end
      end
    end
  end
end
