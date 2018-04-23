# avalon-cloud-install
Some scripts to install avalon (and required packages) on a freshly provisioned Compute Canada Ubuntu 16.04 cloud instance with docker

## How to use
1. Provision a 16.04 ubuntu image on the Compute Canada cloud with an external facing IP.
2. scp either the avalon 5 or avalon 6 script to the cloud instance.
3. Run the script using bash to install avalon and it's dependency, and to stand up the stack using docker compose.
