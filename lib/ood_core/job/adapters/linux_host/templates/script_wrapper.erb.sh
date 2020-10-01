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

echo $hostname

# Put the script into a temp file on localhost
singularity_tmp_file=$(mktemp -p "<%= workdir %>" --suffix '_sing')
tmux_tmp_file=$(mktemp -p "<%= workdir %>" --suffix "_tmux")


# Create an executable to run in a tmux session
# The escaped HEREDOC means that we need to substitute in $singularity_tmp_file ourselves
cat << 'TMUX_LAUNCHER' | sed "s#\$singularity_tmp_file#${singularity_tmp_file}#" > "$tmux_tmp_file"
#!/bin/bash
<% if email_on_terminated %>
exit_script() {
<%# DO NOT INDENT email_on_terminated may have HEREDOCS %>
<%= email_on_terminated %>
trap - SIGINT SIGTERM # clear the trap
kill -- -$$ # Sends SIGTERM to child/sub processes
}
trap exit_script SIGINT SIGTERM
<% end %>

<%= cd_to_workdir %>
<%= environment %>

<%= email_on_start %>

# Redirect stdout and stderr to separate files for all commands run within the curly braces
# https://unix.stackexchange.com/a/6431/204548
# Swap sterr and stdout after stdout has been redirected
# https://unix.stackexchange.com/a/61932/204548
OUTPUT_PATH=<%= output_path %>
ERROR_PATH=<%= error_path %>
({
timeout <%= script_timeout %>s <%= singularity_bin %> exec <%= contain %> --pid <%= singularity_image %> /bin/bash --login $singularity_tmp_file <%= arguments %>
} | tee "$OUTPUT_PATH") 3>&1 1>&2 2>&3 | tee "$ERROR_PATH"

<%= email_on_terminated %>

# Exit the tmux session when we are complete
exit 0
TMUX_LAUNCHER

# Create an executable for Singularity to run
# Escaped HEREDOC means that we do not have to worry about Shell.escape-ing script_content
cat << 'SINGULARITY_LAUNCHER' > "$singularity_tmp_file"
<%= script_content %>
SINGULARITY_LAUNCHER

# Run the script inside a tmux session
chmod +x "$singularity_tmp_file"
chmod +x "$tmux_tmp_file"
<%= tmux_bin %> new-session -d -s "<%= session_name %>" "$tmux_tmp_file"
