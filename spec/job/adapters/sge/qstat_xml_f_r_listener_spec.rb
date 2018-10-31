require "spec_helper"
require "ood_core/job/adapters/sge/qstat_xml_f_r_listener"

describe QstatXmlFrListener do
  subject(:listener) { described_class.new }

  describe ":parsed_jobs" do
    context "Multiple results are returned" do
      let(:qstat_output) { <<-HEREDOC
<?xml version='1.0'?>
<job_info  xmlns:xsd="http://gridengine.sunsource.net/source/browse/*checkout*/gridengine/source/dist/util/resources/schemas/qstat/qs
tat.xsd?revision=1.11">
  <queue_info>
    <Queue-List>
      <name>general.q@worker</name>
      <qtype>BIP</qtype>
      <slots_used>1</slots_used>
      <slots_resv>0</slots_resv>
      <slots_total>1</slots_total>
      <arch>lx26-amd64</arch>
      <resource name="arch" type="hl">lx26-amd64</resource>
      <resource name="num_proc" type="hl">1</resource>
      <resource name="mem_total" type="hl">489.848M</resource>
      <resource name="swap_total" type="hl">0.000</resource>
      <resource name="virtual_total" type="hl">489.848M</resource>
      <resource name="load_avg" type="hl">0.010000</resource>
      <resource name="load_short" type="hl">0.000000</resource>
      <resource name="load_medium" type="hl">0.010000</resource>
      <resource name="load_long" type="hl">0.050000</resource>
      <resource name="mem_free" type="hl">377.027M</resource>
      <resource name="swap_free" type="hl">0.000</resource>
      <resource name="virtual_free" type="hl">377.027M</resource>
      <resource name="mem_used" type="hl">112.820M</resource>
      <resource name="swap_used" type="hl">0.000</resource>
      <resource name="virtual_used" type="hl">112.820M</resource>
      <resource name="cpu" type="hl">0.100000</resource>
      <resource name="m_topology" type="hl">NONE</resource>
      <resource name="m_topology_inuse" type="hl">NONE</resource>
      <resource name="m_socket" type="hl">0</resource>
      <resource name="m_core" type="hl">0</resource>
      <resource name="np_load_avg" type="hl">0.010000</resource>
      <resource name="np_load_short" type="hl">0.000000</resource>
      <resource name="np_load_medium" type="hl">0.010000</resource>
      <resource name="np_load_long" type="hl">0.050000</resource>
      <resource name="qname" type="qf">general.q</resource>
      <resource name="hostname" type="qf">worker</resource>
      <resource name="slots" type="qc">0</resource>
      <resource name="tmpdir" type="qf">/tmp</resource>
      <resource name="seq_no" type="qf">0</resource>
      <resource name="rerun" type="qf">0.000000</resource>
      <resource name="calendar" type="qf">NONE</resource>
      <resource name="s_rt" type="qf">infinity</resource>
      <resource name="h_rt" type="qf">infinity</resource>
      <resource name="s_cpu" type="qf">infinity</resource>
      <resource name="h_cpu" type="qf">infinity</resource>
      <resource name="s_fsize" type="qf">infinity</resource>
      <resource name="h_fsize" type="qf">infinity</resource>
      <resource name="s_data" type="qf">infinity</resource>
      <resource name="h_data" type="qf">infinity</resource>
      <resource name="s_stack" type="qf">infinity</resource>
      <resource name="h_stack" type="qf">infinity</resource>
      <resource name="s_core" type="qf">infinity</resource>
      <resource name="h_core" type="qf">infinity</resource>
      <resource name="s_rss" type="qf">infinity</resource>
      <resource name="h_rss" type="qf">infinity</resource>
      <resource name="s_vmem" type="qf">infinity</resource>
      <resource name="h_vmem" type="qf">infinity</resource>
      <resource name="min_cpu_interval" type="qf">00:00:01</resource>
      <job_list state="running">
        <JB_job_number>88</JB_job_number>
        <JAT_prio>0.75000</JAT_prio>
        <JB_name>job_15</JB_name>
        <JB_owner>vagrant</JB_owner>
        <JB_project>project_a</JB_project>
        <state>r</state>
        <JAT_start_time>2018-10-10T14:37:16</JAT_start_time>
        <slots>1</slots>
        <full_job_name>job_15</full_job_name>
        <hard_request name="h_rt" resource_contribution="0.000000">360</hard_request>
        <hard_req_queue>general.q</hard_req_queue>
      </job_list>
    </Queue-List>
  </queue_info>
  <job_info>
    <job_list state="pending">
      <JB_job_number>1045</JB_job_number>
      <JAT_prio>0.25000</JAT_prio>
      <JB_name>job_RQ</JB_name>
      <JB_owner>vagrant</JB_owner>
      <JB_project>project_b</JB_project>
      <state>qw</state>
      <JB_submission_time>2018-10-09T18:47:05</JB_submission_time>
      <slots>1</slots>
      <full_job_name>job_RQ</full_job_name>
      <hard_request name="h_rt" resource_contribution="0.000000">360</hard_request>
      <hard_req_queue>general.q</hard_req_queue>
    </job_list>
    <job_list state="pending">
      <JB_job_number>1046</JB_job_number>
      <JAT_prio>0.25000</JAT_prio>
      <JB_name>job_RR</JB_name>
      <JB_owner>vagrant</JB_owner>
      <state>qw</state>
      <JB_submission_time>2018-10-09T18:47:05</JB_submission_time>
      <slots>1</slots>
      <full_job_name>job_RR</full_job_name>
      <hard_request name="h_rt" resource_contribution="0.000000">360</hard_request>
      <hard_req_queue>general.q</hard_req_queue>
    </job_list>
    <job_list state="pending">
      <JB_job_number>44</JB_job_number>
      <JAT_prio>0.00000</JAT_prio>
      <JB_name>c_d</JB_name>
      <JB_owner>vagrant</JB_owner>
      <state>hqw</state>
      <JB_submission_time>2018-10-09T18:35:12</JB_submission_time>
      <slots>1</slots>
      <full_job_name>c_d</full_job_name>
      <hard_request name="h_rt" resource_contribution="0.000000">360</hard_request>
      <hard_req_queue>general.q</hard_req_queue>
    </job_list>
  </job_info>
</job_info>
HEREDOC
      }

      let(:expected_job_infos) {[
        { # Running job, w/ project
          :id => '88',
          :job_owner => 'vagrant',
          :accounting_id => 'project_a',
          :job_name => 'job_15',
          :status => 'r',
          :procs => 1,
          :queue_name => 'general.q',
          :dispatch_time => DateTime.parse('2018-10-10T14:37:16').to_time.to_i,
          :wallclock_limit => 360
        }, { # Queued job, w/ project
          :id => '1045',
          :job_owner => 'vagrant',
          :accounting_id => 'project_b',
          :job_name => 'job_RQ',
          :status => 'qw',
          :procs => 1,
          :queue_name => 'general.q',
          :submission_time => DateTime.parse('2018-10-09T18:47:05').to_time.to_i,
          :wallclock_limit => 360
        }, { # Queued job w/o project
          :id => '1046',
          :job_owner => 'vagrant',
          :job_name => 'job_RR',
          :status => 'qw',
          :procs => 1,
          :queue_name => 'general.q',
          :submission_time => DateTime.parse('2018-10-09T18:47:05').to_time.to_i,
          :wallclock_limit => 360
        }, { # Held job w/o project
          :id => '44',
          :job_owner => 'vagrant',
          :job_name => 'c_d',
          :status => 'hqw',
          :procs => 1,
          :queue_name => 'general.q',
          :submission_time => DateTime.parse('2018-10-09T18:35:12').to_time.to_i,
          :wallclock_limit => 360
        }
      ]}

      before {
        parser = REXML::Parsers::StreamParser.new(qstat_output, listener)
        parser.parse
      }

      it { expect(listener.parsed_jobs).to eq(expected_job_infos) }
    end
  end
end