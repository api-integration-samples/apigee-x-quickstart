# Apigee X Quickstart
This guide does a quickstart of a free instance of Apigee X in a Google Cloud project. After running this quickstart, you can start using Apigee X without any further steps.

Resources created in this quickstart:
- Apigee organization
- A default network
- A load balancer to access the Apigee published APIs on with a default HTTPS certificate
- A dev environment and environment group configured for the load balancer host

As prerequisites you need:
- A Google Cloud project
- Your Google Cloud user needs to have these roles (or Owner)
  - Apigee Organization Admin
  - Service Usage Admin
  - Compute Network Admin
  - Cloud KMS Admin
  - Compute Admin

```sh
#first copy the 1.env.sh file and add your environment variables
cp 1.env.sh 1.env.local.sh
# edit 1.env.loca.sh with your environment variables
source 1.env.local.sh

# do provisioning
./2.provision.sh

# open Apigee console
open "https://console.cloud.google.com/apigee"
```
In case of questions just ask here in the issues.