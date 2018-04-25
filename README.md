# avalon-cloud-install
Some scripts to install avalon (and required packages) on a freshly provisioned Compute Canada Ubuntu 16.04 cloud instance with docker

## How to use
1. Provision a 16.04 ubuntu image on the Compute Canada cloud with an external facing IP.
2. scp either the avalon 5 or avalon 6 script to the cloud instance.
3. Run the script using bash to install avalon and it's dependency, and to stand up the stack using docker compose.

## Differences

* Avalon 6 clones the `develop` branch of upstream `avalon`. The app source and the `docker-compose.yml` file are in the same directory
* Avalon 5 clones the `docker-on-compute-canada` branch of our `avalon` repo (very close to what is currently in our master). It also clones the `ualberta_avalon_dev_environment` branch of our `avalon-docker` repo. The website is served from the `avalon` code, but the `docker-compose` services are run from the `avalon-docker` code.
