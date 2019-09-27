#!/bin/bash
hostname

# Put the script into a temp file on localhost
<% if debug %>
singularity_tmp_file=$(mktemp -p "$HOME" --suffix '_sing')
tmux_tmp_file=$(mktemp -p "$HOME" --suffix "_tmux")
<% else %>
singularity_tmp_file=$(mktemp)
tmux_tmp_file=$(mktemp)
<% end %>

# Create an executable to run in a tmux session
cat << TMUX_LAUNCHER > "$tmux_tmp_file"
#!/bin/bash
<%= cd_to_workdir %>
<%= environment %> 

# Redirect stdout and stderr to separate files for all commands run within the curly braces
# https://unix.stackexchange.com/a/6431/204548
# Swap sterr and stdout after stdout has been redirected
# https://unix.stackexchange.com/a/61932/204548
({
timeout <%= script_timeout %>s <%= singularity_bin %> exec --pid <%= singularity_image %> /bin/bash --login $singularity_tmp_file
} | tee "<%= output_path %>") 3>&1 1>&2 2>&3 | tee "<%= error_path %>"

# Exit the tmux session when we are complete
exit 0
TMUX_LAUNCHER

# Create an executable for Singularity to run
cat << SINGULARITY_LAUNCHER > "$singularity_tmp_file"
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
