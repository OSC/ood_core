require 'test_helper'
require 'open3'
require 'ood_core/batch_connect/templates/selkies'

class SelkiesTest < Minitest::Test
  include TestHelper

  def selkies_template(context = {})
    OodCore::BatchConnect::Templates::Selkies.new({ work_dir: '/tmp/work' }.merge(context))
  end

  def rendered(context = {})
    selkies_template(context).to_s
  end

  def test_requires_work_dir
    error = assert_raises(ArgumentError) { OodCore::BatchConnect::Templates::Selkies.new }

    assert_match(/Missing argument: work_dir/, error.message)
  end

  # #to_s

  def test_renders_a_script_bash_can_parse
    _, stderr, status = Open3.capture3('bash', '-n', stdin_data: rendered)

    assert(status.success?, stderr)
  end

  def test_writes_only_host_port_and_session_token_to_connection_file
    assert_includes(rendered, 'echo -e "host: $host\nport: $port\npassword: $password" > "connection.yml"')
  end

  def test_picks_port_and_generates_both_tokens_before_launcher_starts
    script = rendered

    assert_includes(script, <<~'BASH'.chomp)
      port=$(find_port "${host}")
      [[ $? -eq 0 ]] || clean_up 1
      password=$(create_passwd "32")
    BASH
    assert_includes(script, <<~'BASH'.chomp)
      SELKIES_MASTER_TOKEN=$(create_passwd "32")
      export SELKIES_MASTER_TOKEN
    BASH
  end

  def test_passes_master_token_to_containers_started_with_clean_environment
    script = rendered

    assert_includes(script, 'export APPTAINERENV_SELKIES_MASTER_TOKEN="${SELKIES_MASTER_TOKEN}"')
    assert_includes(script, 'export SINGULARITYENV_SELKIES_MASTER_TOKEN="${SELKIES_MASTER_TOKEN}"')
  end

  def test_starts_selkies_for_portal_proxy_without_login_or_tls
    script = rendered

    assert_includes(script, <<~'BASH'.chomp)
      local args=(--public --port="${port}" --enable-basic-auth=false --enable-https=false --allowed-origins='*')
    BASH
    assert_includes(script, 'exec selkies-session "${args[@]}"' + "\n")
  end

  def test_runs_app_script_as_desktop_and_ends_session_when_it_returns
    script = rendered

    assert_includes(script, <<~'BASH'.chomp)
      args+=(--session="bash -c $(printf '%q' "$1; kill -TERM ${launcher_pid}")")
    BASH
    assert_includes(script, %(selkies_launch \\"./script.sh\\" &\n))
  end

  def test_waits_for_selkies_and_gives_up_once_launcher_exits_or_time_passes
    script = rendered

    assert_includes(script, 'selkies_deadline=$((SECONDS + ${SELKIES_TIMEOUT_SECONDS:-120}))')
    assert_includes(script, %q{until curl -fs -o /dev/null --noproxy '*' --max-time 2 "http://${host}:${port}/api/health"; do})
    assert_includes(script, 'if ! kill -0 "${SCRIPT_PID}" 2>/dev/null || (( SECONDS >= selkies_deadline )); then')
  end

  def test_provisions_session_token_with_both_tokens_off_command_line_and_away_from_proxies
    assert_includes(rendered, <<~'BASH'.chomp)
      curl -fsS -o /dev/null --max-time 10 --config - <<SELKIES_TOKENS || clean_up 1
      url = "http://${host}:${port}/api/tokens"
      noproxy = "*"
      header = "Authorization: Bearer ${SELKIES_MASTER_TOKEN}"
      header = "Content-Type: application/json"
      data = {"${password}":{"role":"controller","slot":1}}
      SELKIES_TOKENS
    BASH
  end

  def test_provisions_session_token_before_writing_connection_file
    script = rendered

    assert_operator(script.index("SELKIES_TOKENS\necho"), :<, script.index('# Create the connection yaml file'))
  end

  def test_stops_launcher_when_job_cleans_up
    assert_includes(rendered, 'if [[ -n "${SCRIPT_PID}" ]] && kill -TERM "${SCRIPT_PID}" 2>/dev/null; then')
  end

  def test_times_out_desktop_when_app_sets_timeout_for_its_script
    assert_includes(rendered(timeout: '30'), %(selkies_launch timeout\\ 30\\ \\"./script.sh\\" &\n))
  end

  # an installed desktop the app names

  def test_starts_named_desktop_as_one_argument_in_place_of_app_script
    script = rendered(selkies_session: 'startxfce4 --replace')

    assert_includes(script, %q{--allowed-origins='*' --session=startxfce4\ --replace)})
    assert_includes(script, "\nselkies_launch &\n")
  end

  def test_starts_named_desktop_in_home
    assert_includes(rendered(selkies_session: 'startxfce4 --replace'), "cd ~ || exit 1\n")
  end

  def test_starts_launcher_without_session_for_default_desktop
    script = rendered(selkies_session: '')

    assert_includes(script, %q{--allowed-origins='*')})
    assert_includes(script, "\nselkies_launch &\n")
  end

  def test_uses_custom_options_in_generated_script
    script = rendered(
      selkies_cmd: 'apptainer exec --nv /opt/selkies.sif selkies-session',
      selkies_args: '--wayland',
      selkies_timeout_seconds: '300',
      password_size: 48
    )

    assert_includes(script, 'exec apptainer exec --nv /opt/selkies.sif selkies-session "${args[@]}" --wayland')
    assert_includes(script, 'selkies_deadline=$((SECONDS + 300))')
    assert_includes(script, 'password=$(create_passwd "48")')
  end

  def test_factory_builds_selkies_template_from_config
    template = OodCore::BatchConnect::Factory.build(template: 'selkies', work_dir: '/tmp/work')

    assert_instance_of(OodCore::BatchConnect::Templates::Selkies, template)
  end
end
