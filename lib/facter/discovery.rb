# gem install oci --no-document
require 'oci'
require "net/http"
require "uri"
require "yaml"

################################################
# void debug_msg ( string txt )
# Used to dump debug messages if debug is set
# $debug = "/tmp/oci_tag_facts.log"

def debug_msg(txt)
  if $debug.is_a? String
    File.open($debug, 'a') { |file| file.write(Time.now.strftime("%Y/%m/%d %H:%M") + " " + txt + "\n") }
  end
end

if File.file?('tags.yaml')
  tags = YAML.load_file('tags.yaml')
else
  tags = {"namespace"=>"peoplesoft", "grouping"=>"failovergroup", "environment"=>"tier"}
end

# Get ocid of current instance
begin
  uri = URI.parse("http://169.254.169.254")
  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 4
  http.read_timeout = 4
  request = Net::HTTP::Get.new("/opc/v2/instance/id")
  request['Authorization'] = "Bearer Oracle"
  response = http.request(request)
  instance_id = response.body
rescue
  p "(This is not an OCI Compute instance or unable to contact the OCI instance-data web server."
  exit 1
end

instance_principals_signer = OCI::Auth::Signers::InstancePrincipalsSecurityTokenSigner.new
compute_client = OCI::Core::ComputeClient.new(config: OCI::Config.new, signer: instance_principals_signer)
vcn_client = OCI::Core::VirtualNetworkClient.new(config: OCI::Config.new, signer: instance_principals_signer)

# Get compartment id of current instance
begin
  current = compute_client.get_instance(instance_id).data
  compartmentid = current.compartment_id
  current_environment = current.defined_tags[tags['namespace']][tags['environment']]
rescue
  p "Unable to get compartment id for instance"
  exit 1
end

# PIA Failover Groups
pia_failover_group = []
compute_client.list_instances(compartmentid).data.each { |inst|
  if inst.defined_tags[tags['namespace']][tags['grouping']] == 'pia' then
    if inst.defined_tags[tags['namespace']][tags['environment']] == current_environment then
      compute_client.list_vnic_attachments(compartmentid, instance_id: inst.id).each { |vnic_attachments|
        vnic_attachments.data.each { |attachment|
          vnic = vcn_client.get_vnic(attachment.vnic_id).data
          pia_failover_group.push(vnic.private_ip + ":%{hiera('jolt_port')}")
        }
      }
    end
  end
}

Facter.add(:pia_failover_group) do
  setcode do
    pia_failover_group.join(', ')
  end
end

# IB Gateway Failover Groups
ib_failover_group = []
compute_client.list_instances(compartmentid).data.each { |inst|
  if inst.defined_tags[tags['namespace']][tags['grouping']] == 'ib' then
    if inst.defined_tags[tags['namespace']][tags['environment']] == current_environment then
      compute_client.list_vnic_attachments(compartmentid, instance_id: inst.id).each { |vnic_attachments|
        vnic_attachments.data.each { |attachment|
          vnic = vcn_client.get_vnic(attachment.vnic_id).data
          pia_failover_group.push(vnic.private_ip + ":%{hiera('jolt_port')}")
        }
      }
    end
  end
}

Facter.add(:ib_failover_group) do
  setcode do
    ib_failover_group.join(',')
  end
end
