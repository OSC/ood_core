if command -v mail; then
cat << EMAIL_CONTENT | mail -s "Job <%= job_name %> has <%= job_status %>" <%= email_recipients %>
Greetings,

Your job <%= job_name %> has <%= job_status %>.

- The OnDemand Linux Host Adapter
EMAIL_CONTENT
fi