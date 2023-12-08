require "ood_core/refinements/hash_extensions"
require "securerandom"

module OodCore
  module BatchConnect
    class Factory
      using Refinements::HashExtensions

      # Build the VNC template from a configuration
      # @param config [#to_h] the configuration for the batch connect template
      def self.build_vnc_container(config)
        context = config.to_h.symbolize_keys.reject { |k, _| k == :template }
        
        unless context.key?(:container_path)
          raise JobAdapterError, "You are missing the configuration 'container_path' for a vnc_container template."
        end

        Templates::VNC_Container.new(context)
      end
    end

    module Templates
      # A batch connect template that starts up a VNC server within a batch job
      class VNC_Container < Template
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
        # @option context [#to_s] :container_path ("vnc_container.sif") the path
        #   to the container with VNC
        # @option context [#to_s] :container_bindpath ("") paths to bind into
        #   the container with VNC
        # @option context [#to_s] :container_module ("singularity") the module
        #   that loads Singularity or Apptainer with Lmod. Supports versions (i.e.
        #   apptainer/1.10). If Singularity or Apptainer are installed at a 
        #   system level (i.e., no module loaded to activate), set this to an
        #   empty string.
        # @option context [#to_s] :container_command ("singularity") the 
        #   singularity or apptainer execution command
        # @option context [#to_a] :container_start_args ([]) Additional
        #   arguements you wish to pass to the container start command.
        # @param instance_name (uuid) a name for the instance
        # @see Template

        def initialize(context = {})
          @instance_name = SecureRandom.uuid
          super
        end

        private
          # We need to know the VNC and websockify connection information
          def conn_params
            (super + [:display, :websocket, :spassword, :instance_name]).uniq
          end

          # Before running the main script, start up a VNC server and record
          # the connection information
          def before_script
            container_path = context.fetch(:container_path, "vnc_container.sif").to_s
            container_bindpath = context.fetch(:container_bindpath, "").to_s

            <<-EOT.gsub(/^ {14}/, "")

              # Load #{container_module}
              echo "Loading #{container_module}..."
              module load #{container_module}
              export #{container_command.upcase}_BINDPATH="#{container_bindpath}"
              export INSTANCE_NAME="#{@instance_name}"
              export instance_name="#{@instance_name}"
              echo "Starting instance..."
              #{container_command} instance start #{container_start_args} #{container_path} #{@instance_name}

              # Setup one-time use passwords and initialize the VNC password
              function change_passwd () {
                echo "Setting VNC password..."
                password=$(create_passwd "#{password_size}")
                spassword=${spassword:-$(create_passwd "#{password_size}")}
                (
                  umask 077
                  echo -ne "${password}\\n${spassword}" | #{container_command} exec instance://#{@instance_name} vncpasswd -f > "#{vnc_passwd}"
                )
              }
              change_passwd

              
              # Start up vnc server (if at first you don't succeed, try, try again)
              echo "Starting VNC server..."
              for i in $(seq 1 10); do
                # Clean up any old VNC sessions that weren't cleaned before
                #{vnc_clean}

                # for turbovnc 3.0 compatability.
                if timeout 2 #{container_command} exec instance://#{@instance_name} vncserver --help 2>&1 | grep 'nohttpd' >/dev/null 2>&1; then
                  HTTPD_OPT='-nohttpd'
                fi

                # Attempt to start VNC server
                VNC_OUT=$(#{container_command} exec instance://#{@instance_name} vncserver -log "#{vnc_log}" -rfbauth "#{vnc_passwd}" $HTTPD_OPT -noxstartup #{vnc_args} 2>&1)
                VNC_PID=$(pgrep -s 0 Xvnc) # the script above will daemonize the Xvnc process
                echo "${VNC_PID}"
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
              module load #{container_module}
              echo "Starting websocket server..."
              websocket=$(find_port)
              [ $? -eq 0 ] || clean_up 1 # give up if port not found
              #{container_command} exec instance://#{@instance_name} #{websockify_cmd} -D ${websocket} localhost:${port}

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
              module load #{container_module}

              #{vnc_clean}
              [[ -n ${display} ]] && vncserver -kill :${display}
              #{container_command} instance stop #{@instance_name}
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

          def container_module 
            context.fetch(:container_module, "singularity").to_s
          end

          def container_command 
            context.fetch(:container_command, "singularity").to_s
          end

          def container_start_args
            context.fetch(:container_start_args, []).to_a.join(' ')
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
              %(#{container_command} exec instance://#{@instance_name} vncserver -list | awk '/^:/{system("kill -0 "$2" 2>/dev/null || #{container_command} exec instance://#{@instance_name} vncserver -kill "$1)}')
            end.to_s
          end
      end
    end
  end
end
