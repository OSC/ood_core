require "ood_core/refinements/hash_extensions"

module OodCore
  module BatchConnect
    class Factory
      using Refinements::HashExtensions

      # Build the VNC template from a configuration
      # @param config [#to_h] the configuration for the batch connect template
      def self.build_vnc(config)
        context = config.to_h.symbolize_keys.reject { |k, _| k == :template }
        Templates::VNC.new(context)
      end
    end

    module Templates
      # A batch connect template that starts up a VNC server within a batch job
      class VNC < Template
        # @param context [#to_h] the context used to render the template
        # @option context [#to_sym, Array<#to_sym>] :conn_params ([]) A list of
        #   connection parameters added to the connection file (`:host`,
        #   `:port`, `:password`, `:spassword`, `:display` and `:websocket`
        #   will always exist)
        # @option context [#to_s] :websockify_cmd
        #   ("${WEBSOCKIFY_CMD:-/opt/websockify/run}") the path to the
        #   websockify script (assumes you don't modify `:after_script`)
        # @option context [#to_s] :vnc_log ("vnc.log") path to vnc server log
        #   file (assumes you don't modify `:before_script` or `:after_script`)
        # @option context [#to_s] :vnc_passwd ("vnc.passwd") path to the file
        #   generated that contains the encrypted vnc password (assumes you
        #   don't modify `:before_script`)
        # @option context [#to_s] :vnc_args arguments used when starting up the
        #   vnc server (overrides any specific vnc argument) (assumes you don't
        #   modify `:before_script`)
        # @option context [#to_s] :name ("") name of the vnc server session
        #   (not set if blank or `:vnc_args` is set) (assumes you don't modify
        #   `:before_script`)
        # @option context [#to_s] :geometry ("") resolution of vnc display (not
        #   set if blank or `:vnc_args` is set) (assumes you don't modify
        #   `:before_script`)
        # @option context [#to_s] :dpi ("") dpi of vnc display (not set if
        #   blank or `:vnc_args` is set) (assumes you don't modify
        #   `:before_script`)
        # @option context [#to_s] :fonts ("") command delimited list of fonts
        #   available in vnc display (not set if blank or `:vnc_args` is set)
        #   (assumes you don't modify `:before_script`)
        # @option context [#to_s] :idle ("") timeout vnc server if no
        #   connection in this amount of time in seconds (not set if blank or
        #   `:vnc_args` is set) (assumes you don't modify `:before_script`)
        # @option context [#to_s] :extra_args ("") any extra arguments used
        #   when initializing the vnc server process (not set if blank or
        #   `:vnc_args` is set) (assumes you don't modify `:before_script`)
        # @option context [#to_s] :vnc_clean ("...") script used to clean up
        #   any active vnc sessions (assumes you don't modify `:before_script`
        #   or `:clean_script`)
        # @see Template
        def initialize(context = {})
          super
        end

        private
          # We need to know the VNC and websockify connection information
          def conn_params
            (super + [:display, :websocket, :spassword]).uniq
          end

          # Before running the main script, start up a VNC server and record
          # the connection information
          def before_script
            <<-EOT.gsub(/^ {14}/, "")
              # Setup one-time use passwords and initialize the VNC password
              function change_passwd () {
                echo "Setting VNC password..."
                password=$(create_passwd "#{password_size}")
                spassword=${spassword:-$(create_passwd "#{password_size}")}
                (
                  umask 077
                  echo -ne "${password}\\n${spassword}" | vncpasswd -f > "#{vnc_passwd}"
                )
              }
              change_passwd

              # Start up vnc server (if at first you don't succeed, try, try again)
              echo "Starting VNC server..."
              for i in $(seq 1 10); do
                # Clean up any old VNC sessions that weren't cleaned before
                #{vnc_clean}

                # Attempt to start VNC server
                VNC_OUT=$(vncserver -log "#{vnc_log}" -rfbauth "#{vnc_passwd}" -nohttpd -noxstartup #{vnc_args} 2>&1)
                VNC_PID=$(pgrep -s 0 Xvnc) # the script above will daemonize the Xvnc process
                echo "${VNC_OUT}"

                # Sometimes Xvnc hangs if it fails to find working disaply, we
                # should kill it and try again
                kill -0 ${VNC_PID} 2>/dev/null && [[ "${VNC_OUT}" =~ "Fatal server error" ]] && kill -TERM ${VNC_PID}

                # Check that Xvnc process is running, if not assume it died and
                # wait some random period of time before restarting
                kill -0 ${VNC_PID} 2>/dev/null || sleep 0.$(random_number 1 9)s

                # If running, then all is well and break out of loop
                kill -0 ${VNC_PID} 2>/dev/null && break
              done

              # If we fail to start it after so many tries, then just give up
              kill -0 ${VNC_PID} 2>/dev/null || clean_up 1

              # Parse output for ports used
              display=$(echo "${VNC_OUT}" | awk -F':' '/^Desktop/{print $NF}')
              port=$((5900+display))

              echo "Successfully started VNC server on ${host}:${port}..."

              #{super}
            EOT
          end

          # Run the script under the VNC server's display
          def run_script
            %(DISPLAY=:${display} #{super})
          end

          # After startup the main script, scan the VNC server log file for
          # successful connections so that the password can be reset
          def after_script
            websockify_cmd = context.fetch(:websockify_cmd, "${WEBSOCKIFY_CMD:-/opt/websockify/run}").to_s

            <<-EOT.gsub(/^ {14}/, "")
              #{super}

              # Launch websockify websocket server
              echo "Starting websocket server..."
              websocket=$(find_port)
              #{websockify_cmd} -D ${websocket} localhost:${port}

              # Set up background process that scans the log file for successful
              # connections by users, and change the password after every
              # connection
              echo "Scanning VNC log file for user authentications..."
              while read -r line; do
                if [[ ${line} =~ "Full-control authentication enabled for" ]]; then
                  change_passwd
                  create_yml
                fi
              done < <(tail -f --pid=${SCRIPT_PID} "#{vnc_log}") &
            EOT
          end

          # Clean up the running VNC server and any other stale VNC servers
          def clean_script
            <<-EOT.gsub(/^ {14}/, "")
              #{super}

              #{vnc_clean}
              [[ -n ${display} ]] && vncserver -kill :${display}
            EOT
          end

          # Log file for VNC server
          def vnc_log
            context.fetch(:vnc_log, "vnc.log").to_s
          end

          # Password file for VNC server
          def vnc_passwd
            context.fetch(:vnc_passwd, "vnc.passwd").to_s
          end

          # Arguments sent to `vncserver` command
          def vnc_args
            context.fetch(:vnc_args) do
              name       = context.fetch(:name, "").to_s
              geometry   = context.fetch(:geometry, "").to_s
              dpi        = context.fetch(:dpi, "").to_s
              fonts      = context.fetch(:fonts, "").to_s
              idle       = context.fetch(:idle, "").to_s
              extra_args = context.fetch(:extra_args, "").to_s

              args = []
              args << "-name #{name}" unless name.empty?
              args << "-geometry #{geometry}" unless geometry.empty?
              args << "-dpi #{dpi}" unless dpi.empty?
              args << "-fp #{fonts}" unless fonts.empty?
              args << "-idletimeout #{idle}" unless idle.empty?
              args << extra_args

              args.join(" ")
            end.to_s
          end

          # Clean up any stale VNC sessions
          def vnc_clean
            context.fetch(:vnc_clean) do
              %(vncserver -list | awk '/^:/{system("kill -0 "$2" 2>/dev/null || vncserver -kill "$1)}')
            end.to_s
          end
      end
    end
  end
end
