# How to deploy and protect your applications using the TrilioVault for Kubernetes OneClick plugin

**tvk-oneclick** is a kubectl plugin which installs, configures, and test the TrilioVault for Kuberentes (TVK).
It installs the TVK Operator, the TVM Application, configures the TVK Management Console, and executes sample backup and restore operations.

## Pre-requisites:

Users need to run a script **install_prereq.sh** to install the pre-requisites required for TVK-OneClick plugin.

**NOTE:** Users should have **root** previledges to run the **install_prereq.sh** script. 
If any of the prerequisites fail to install due to environment or network access issues, they can be installed individually before running the TVK-OneClick plugin.

1. krew - kubectl-plugin manager. Install from [here](https://krew.sigs.k8s.io/docs/user-guide/setup/install/)
2. kubectl - kubernetes command-line tool. Install from [here](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
3. Helm (version >= 3)
4. Python3(version >= 3.9, with requests package installed - pip3 install requests)
5. S3cmd. Install from [here](https://acloud24.com/blog/installation-and-configuration-of-s3cmd-under-linux/)
6. yq(version >= 4). Information can be found @[here](https://github.com/mikefarah/yq) 


**Supported OS and Architectures**:

OS:
- Linux
- darwin

Arch:
- amd64
- x86


## TVK-OneClick plugin performs the following tasks:

- Preflight check:
	Performs preflight checks to ensure that all requirements are satisfied.
- **TVK Installation and Management Console Configuration**:
	**TVK installation, Management Console configuration and License installation is done from DO Marketplace (https://marketplace.digitalocean.com/apps/triliovault-for-kubernetes)** 
- TVK Management Console Configuration:
        Even after above configuation, users has an option to choose from ['Loadbalancer','Nodeport','PortForwarding'] to access the console using TVK-OneClick plugin.
- Target Creation:
	Creates and validate the target where backups are stored. Users can create S3 (DigitalOCean Spaces / AWS S3) or NFS based target.  
- Run Sample Tests of Backup and Restore:
        Run sample tests for ['Label_based','Namespace_based','Operator_based','Helm_based'] applications. By default, 'Label_based' backup tests are run against a MySQL Database application, 'Namespace_based' tests against a Wordpress application, 'Operator_based' tests against Postgress operator application,'Helm_based' tests against a Mongo Database helm based application.


## Installation, Upgrade, Removal of Plugins :

- Add TVK custom plugin index of krew:

  ```
  kubectl krew index add tvk-plugins https://github.com/trilioData/tvk-plugins.git
  ```

- Installation:

  ```
  kubectl krew install tvk-plugins/tvk-oneclick
  ```  

- Upgrade:

  ```
  kubectl krew upgrade tvk-oneclick
  ```  

- Removal:

  ```
  kubectl krew uninstall tvk-oneclick
  ```  

## Usage

There are two way to use the TVK-OneClick plugin:
1. Interactive
2. Non-interactive


## Ways to execute the plugin

**1. Interactive**:
        The plugin asks for various inputs that enable it to perform installation and deployment operations. 
        For interactive installation of TVK operator and manager, configure TVK UI, create a target and run samepl backup restore, run below command:

kubectl tvk-oneclick [options] 

Flags:

| Parameter                     | Description   
| :---------------------------- |:-------------:
| -n, --noninteractive          | Run script in non-interactive mode.for this you need to provide config file
| -i, --install_tvk             | Installs TVK and it's free trial license.
| -c, --configure_ui            | Configures TVK UI.
| -t, --target                  | Create Target for backup and restore jobs
| -s, --sample_test		| Create sample backup and restore jobs
| --preflight		        | Checks if all the pre-requisites are satisfied

```shell script
kubectl tvk-oneclick -c -t -s
```

**2. Non-interactive**:
	TVK-OneClick can be executed in a non-interactive method by leveraging values from an input_config file. To use the plugin in a non-interactive way, create an input_config (URL) file. After creating the input config file, run the following command to execute the plugin in a non-interactive fashion. The non-interative method will perform preflight checks, installation, configuration (Management Console and Target) as well as run sample backup and restore tests similar to the interactive mode but in a single workflow.
	Sample input_config file can be found here:
        https://github.com/bhagirathhapse/Kubernetes-Starter-Kit-Developers/blob/main/06-b-triliovault-for-kubernetes/input_config
	This sample_config input file leverages your DO credentials and DO DNS information to create/configure a target within DO Spaces, and to configure the management console leveraging a Kubernetes LoadBalancer.
	The user has to provide their DO credentials (Access key and Secret key) as mandatory inputs and DNS information as Optional inputs if using LoadBalancers for setting up the Management Console. 
	
```shell script
kubectl tvk-oneclick -n
```

## 'input_config' /input parameter details

- **PREFLIGHT**:
	This parameter is to check whether or not preflight should be executed.It accepts one of the value from [True, False]
	More info around this can be found @[here](https://github.com/trilioData/tvk-plugins/tree/main/docs/preflight)
- **proceed_even_PREFLIGHT_fail**:
	This option is dependent of PREFLIGHT execution.If a user wish to proceed even if few checks failed in preflight execution, user need to set this variable to y/Y. This variable accepts one of the value from [Y,y,n,N].
- **TVK_INSTALL**:
	This parameter is to check whether or not TVK should be installed.It accepts one of the value from [True, False]
- **CONFIGURE_UI**:
	This parameter is to check whether or not TVK UI should be configured.It accepts one of the value from [True, False]
- **TARGET**:
	This parameter is to check whether or not TVK Target should be created.It accepts one of the value from [True, False]
- **SAMPLE_TEST**: 
	This parameter is to check whether or not sample test should be executed.It accepts one of the value from [True, False]
- **storage_class**:
	This parameter expects storage_class name which should be used across plugin execution. If kept empty, the storage_class annoted with 'default' label would be considered. If there is no such class, the plugin would likely fail.
- **operator_version**:
	This parameter expects user to specify the TVK operator version to install as a part of tvk installation process.
	The compatibility/bersion can be found @[here](https://docs.trilio.io/kubernetes/use-triliovault/compatibility-matrix#triliovaultmanager-and-tvk-application-compatibility). If this parameter is empty, by default TrilioVault operator version  2.1.0 will get installed.
- **triliovault_manager_version**:
	This parameter expects user to specify the TVK manager version to install as a part of tvk installation process.
        The compatibility/bersion can be found @[here](https://docs.trilio.io/kubernetes/use-triliovault/compatibility-matrix#triliovaultmanager-and-tvk-application-compatibility). If this parameter is empty, by default TrilioVault operator version  2.1.0 will get installed.
- **tvk_ns**:
	This parameter expects user to specify the namespace in which user wish tvk to get installed in.
- **if_resource_exists_still_proceed**:
	This parameter is to check whether plugin should proceed for other operationseven if resources exists.It accepts one of the value from [Y,y,n,N]
- **ui_access_type**:
	Specify the way in which TVK UI should be configured. It accepts one of the value from ['Loadbalancer','Nodeport','PortForwarding']
- **domain**:
	The value of this parameter is required when 'ui_access_type == Loadbalancer'.Specify the domain name which has been registered with a registrar and under which you wish to create record in. More info around this parameter can be found @[here](https://docs.digitalocean.com/products/networking/dns/)
- **tvkhost_name**:
	The value of this parameter is required when 'ui_access_type == Loadbalancer OR ui_access_type == Nodeport'. The value of this parameter will be the hostname by which the TVK management console will be accessible through a web browser.
- **cluster_name**:
	The value of this parameter is required when 'ui_access_type == Loadbalancer OR ui_access_type == Nodeport'. If kept blank, the active cluster name will be taken.
- **vendor_type**:
	The value of this parameter is required to create target. Specify the vendor name under which target needs to be created. Currently supported value is one for the ['Digital_Ocean','Amazon_AWS']
- **doctl_token**:
	The value of this parameter is required to create target. Specify the token name to authorize user.A token that allows it to query and manage DO account details and resources for user.
- **target_type**:
	Target is a location where TrilioVault stores backup.Specify type of target to create.It accepts one of the value from ['NFS','S3']. More information can be found @[here](https://docs.trilio.io/kubernetes/getting-started/getting-started-1#step-2-create-a-target)
- **access_key**:
	This parameter is required when 'target_type == S3'.This is used for bucket S3 access/creation. The value should be consistent with the vendor_type you select.
- **secret_key**:
	This parameter is required when 'target_type == S3'.This is used for bucket S3 access/creation. The value should be consistent with the vendor_type you select.
- **host_base**:
	This parameter is required when 'target_type == S3'.specify the s3 endpoint for the region your Spaces/Buckets are in.
	More information can be found @[here](https://docs.digitalocean.com/products/spaces/resources/s3cmd/#enter-the-digitalocean-endpoint)
- **host_bucket**:
	The value of this parameter should be URL template to access s3 bucket/spaces.This parameter is required when 'target_type == S3'.
	Generally it's value is '%(bucket)s.<value of host_base>' . This is the URL to access the bucket/space.
- **gpg_passphrase**:
	This parameter is for an optional encryption password. Unlike HTTPS, which protects files only while in transit, GPG encryption prevents others from reading files both in transit and while they are stored.  More information can be found @[here](https://docs.digitalocean.com/products/spaces/resources/s3cmd/#optional-set-an-encryption-password)
- **bucket_location**:
	Specify the location where the s3 bucket for target should be created. This parameter is specific to AWS vendor_type.The value can be one from ['us-east-1', 'us-west-1', 'us-west-2', 'eu-west-1', 'eu-central-1', 'ap-northeast-1', 'ap-southeast-1', 'ap-southeast-2', 'sa-east-1'].
- **bucket_name**:
	Specify the name for the bucket to be created or looked for target creation.
- **target_name**:
	Specify the name for the target that needs to be created.
- **target_namespace**:
	Specify the namespace name in which target should be created in. User should have permission to create/modify/access the namespace.
- **nfs_server**:
	The server Ip address or the fully qualified nfs server name. This paramere is required when 'target_type == NFS'
- **nfs_path**:
	Specify the exported path which can be mounted for target creation. This paramere is required when 'target_type == NFS'
- **nfs_options**:
	Specify if any other NFS option needs to be set. Additional values for the nfsOptions field can be found @[here](https://docs.trilio.io/kubernetes/architecture/apis-and-command-line-reference/custom-resource-definitions-application-1#triliovault.trilio.io/v1.NFSCredentials)
- **thresholdCapacity**:
	Capacity at which the IO operations are performed on the target.Units supported - [Mi,Gi,Ti]
- **bk_plan_name**:
	Specify the name for backup plan creation for the sample application. Default value is 'trilio-test-backup'.
- **bk_plan_namespace**:
	Specify the namespace in which the application should get installed and the backup plan will get created. Default value is 'trilio-test-backup'.
- **backup_name**:
	 Specify the name for backup to be created for the sample application. Default value is 'trilio-test-backup'.
- **backup_namespace**:
	Specify the namespace in which backup should get created. Default value is 'trilio-test-backup'.
- **backup_way**:
	Specify the way in which backup should be taken.Supported values  ['Label_based','Namespace_based','Operator_based','Helm_based'].
	For Label_based, MySQL application would be installed and sample backup/restore will be showcased.
	For Namespace_based, Wordpress application would be installed and sample backup/restore will be showcased.
	For Operator_based, MySQL operator  would be installed and sample backup/restore will be showcased.
	For Helm_based, Mongodb  application would be installed and sample backup/restore will be showcased.
- **restore**:
	Specify whether or not restore should be executed. Allowed values are one from the  [True, False] list.
- **restore_name**:
	Specify the name for the restore. Default value is 'tvk-restore'.
- **restore_namespace**:
	Specify the namespace in which backup should be restored. Default value is 'tvk-restore'.
