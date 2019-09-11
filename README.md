# SIGP framework on Azure
Template for Deploying an NFS Server with Premium Storage and Accelerated Networking.

You must specify an existing VNet/Subnet for it to attach to.
This will also assign a PublicIP address to the server.

The DataDiskSize and nbDataDisks parameters refer to the NFS Server.  ndDataDisks of DataDiskSize will be attached to the NFS Server, then they will be formatted and combined into a single RAID 0 volume which will then be exported as the /share/data directory. 

To deploy NFS server

[![Click to deploy headnode template on Azure](http://azuredeploy.net/deploybutton.png "Click to deploy template on Azure")](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fzhifaliu%2FNESDIS_IAAS%2Fmaster%2Fazuredeploy.json)  


To deploy computing node

[![Click to deploy HPC template on Azure](http://azuredeploy.net/deploybutton.png "Click to deploy template on Azure")](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fzhifaliu%2FNESDIS_IAAS%2Fmaster%2FdeployComputeNodes.json)  


