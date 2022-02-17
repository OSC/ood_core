#!/bin/bash
SSH_HOSTS=(<%= ssh_hosts.join(' ').to_s %>)
hostnames=`hostname -A`
for host in ${SSH_HOSTS[@]}
do
    if [[ " ${hostnames[@]} " =~ " ${host} " ]]; then
        hostname=$host
    fi
done

if [ -z "$hostname" ]; then
    printf >&2 "ERROR: Can't start job on [${hostnames[@]}] because it does not match any hostname configured \nin ssh_hosts [${SSH_HOSTS[@]}]. The output of 'hostname -A' must match an entry in ssh_hosts \nfrom the cluster configuration."
    exit 1
fi

echo ""
echo "HOSTNAME:$hostname"

# we need this user to be enabled for lingering or else the newly started
# service will end as soon as the ssh session starting has exited
loginctl enable-linger

# Put the script into a temp file on localhost
systemd_service_file="<%= workdir %>/systemd_service.sh"
systemd_service_file_pre="<%= workdir %>/systemd_pre.sh"
systemd_service_file_post="<%= workdir %>/systemd_post.sh"

cat << 'SYSTEMD_EXEC_PRE' > "$systemd_service_file_pre"
#!/bin/bash
<%= cd_to_workdir %>
<% if email_on_start %>
<%= email_on_start %>
<% end %>
SYSTEMD_EXEC_PRE

cat << 'SYSTEMD_EXEC_POST' > "$systemd_service_file_post"
#!/bin/bash
<%= cd_to_workdir %>
<% if email_on_terminated %>
<%= email_on_terminated %>
<% end %>
SYSTEMD_EXEC_POST

# Create an executable for systemd service to run
# Escaped HEREDOC means that we do not have to worry about Shell.escape-ing script_content
cat << 'SYSTEMD_EXEC' > "$systemd_service_file"
<%= script_content %>
SYSTEMD_EXEC

# Run the script inside a transient systemd user service
chmod +x "$systemd_service_file_pre" "$systemd_service_file" "$systemd_service_file_post"
<%= cd_to_workdir %>
systemd-run --user -r --no-block --unit=<%= session_name %> -p RuntimeMaxSec=<%= script_timeout %> \
	-p ExecStartPre="$systemd_service_file_pre" -p ExecStartPost="$systemd_service_file_post" \
	-p StandardOutput="file:<%= output_path %>" -p StandardError="file:<%= error_path %>" \
	-p Description="<%= job_name %>" "$systemd_service_file"
