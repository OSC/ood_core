#!/bin/bash
hostnames=$(hostname -A)
hostnameFound=false
for host in $SSH_HOSTS
do
    if [[ " ${hostnames[@]} " =~ " ${host} " ]]; then
        hostnameFound=true
        hostname=$host
    fi
done

if [ ! $hostnameFound ]; then
    echo >&2 "ERROR: The specified host is not in the list of ssh hosts configured in this cluster config [${SSH_HOSTS[@]}]. The specified hosts determined by running 'hostname -A' [${hostnames[@]}] on the target host must match one of the configured ssh hosts" 
    exit 1
fi

echo $hostname

# Put the script into a temp file on localhost
<% if debug %>
singularity_tmp_file=$(mktemp -p "$HOME" --suffix '_sing')
tmux_tmp_file=$(mktemp -p "$HOME" --suffix "_tmux")
<% else %>
singularity_tmp_file=$(mktemp)
tmux_tmp_file=$(mktemp)
<% end %>

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

# Remove the file
<% if ! debug %>
# Wait 1 second to ensure that tmux session has started before the file is removed
sleep 1
rm -f "$tmux_tmp_file"; rm -f "$singularity_tmp_file"
<% end %>
