# io_oci_discovery

Simple service discovery using OCI tags to generate PeopleSoft PIA and IB Gateway failover strings for the Deployment Packages.

## Failover Group Discovery

Uses these defaults to looks for tags to associate instances:

* Namespace: `peoplesoft`
* Grouping: `failovergroup`
* Environment Level: `tier`

For example, your HR production web servers would have these tags:

* `peoplesoft.failovergroup=pia`
* `peoplesoft.tier=hrprd`

and any instance that has those tags are returned in a list as the fact `pia_failover_group`

### Default Tag Setup

If you do not have tags setup, there is a helper script that can create the Tag Namespace and Tags to be used by this module. It is intended to be run from OCI's Cloud Shell and will set up the default tags.

```bash
$ ./create_tag_ns.sh

Creating 'peoplesoft' Tag Namespace
Creating 'peoplesoft.failovergroup' Tag
Creating 'peoplesoft.tier' Tag

Tag Namespace and Tags are ready for io_oci_discovery DPK Module.
 - Modify the 'tier' tag values as needed.
```

### Custom Tag Setup

Create the file `$DPK_HOME/modules/io_oci_facts/lib/facter/tags.yaml` with this structure to use non-default tag values:

```yaml
namespace:    'psadminio'
grouping:     'role'
environment:  'zone'
```

You can use existing tags and a namespace or create your own. 

* The "environment" tag is use to identify your DEV, TST, PRD, etc environments. 
* The "grouping" tag is used to identify what type of failover string you need. The defined tag values must be: 
  * `pia`
  * `ib`

## Installation

### DPK Installation

First, install the `oci` gem on each server with the DPK. The module uses the OCI Ruby SDK to query instances in the compartment.

```bash
gem install oci --no-document
```

Cloning the repository:

```bash
$ cd <DPK_LOCATION>
$ git clone https://github.com/psadmin-io/psadminio-io_oci_discovery.git modules/io_oci_discovery
```

As a Git Submodule:

```bash
$ cd <DPK_LOCATION>
$ git submodule add https://github.com/psadmin-io/psadminio-io_oci_discovery.git modules/io_oci_discovery
```

### OCI Requirements

To query other instances for the failover discovery, you need to grant read access to the servers where the DPK is running. This can be done through a dynamic group and a policy.

The dynamic group should include all instances where you are running the DPK (this can be done at the compartment level):

**Dynamic Group Name**: `dpk-read-group`
  * Criteria: `ANY { instance.compartment.id <compartment_id> }`

**Policy Name**: `dpk-read-instance-and-vcn`
  * Policies:
    * `Allow dynamic-group dpk-read-group to read instance-family in compartment <compartment_name>`
    * `Allow dynamic-group dpk-read_group to read virtual-network-family in compartment <compartment_name>`

### Assumptions:

* Looks in current compartment only (where DPK is executed) when discovering other instances with the same tags for the failover groups.
* Default tags and namespace are: `peoplesoft.failovergroup` and `peoplesoft.tier`

## Using Failover Strings

To use the PIA failover string value ([following the dumb vs. smart load balancing setup](https://psadmin.io/2015/12/01/smart-v-dumb-load-balancing/)):

```yaml
pia_psserver_list:        "%{::fqdn}:%{hiera('jolt_port')}{%{::pia_failover_group}}"
```