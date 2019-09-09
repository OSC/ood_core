#!/bin/bash

# Put the script into a temp file on localhost
<% if debug %>
tmp_file=$(mktemp -p "$HOME")
<% else %>
tmp_file=$(mktemp)
<% end %>
cat << HEREDOC > "$tmp_file"
#!/bin/bash
<%= cd_to_workdir %>
<%= environment %>
<%= timeout_cmd %>

# Redirect stdout and stderr to separate files for all commands run within the curly braces
# https://unix.stackexchange.com/a/6431/204548
# Swap sterr and stdout after stdout has been redirected
# https://unix.stackexchange.com/a/61932/204548
(
    {
<%= script_content %>
    } | tee "<%= output_path %>"
) 3>&1 1>&2 2>&3 | tee "<%= error_path %>"

# Exit the tmux session when we are complete
exit 0
HEREDOC

# Run the script inside a tmux session
chmod +x "$tmp_file"
<%= tmux_bin %> new-session -d -s "<%= session_name %>" "$tmp_file"

# Remove the file
<% if ! debug %>
# Wait 1 second to ensure that tmux session has started before the file is removed
(sleep 1; rm -f "$tmp_file") &
<% end %>
