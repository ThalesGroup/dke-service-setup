# Security Policy

## Supported Versions of Luna Key Broker

Always check in the [Thales support portal](https://supportportal.thalesgroup.com/csm?id=csm_product&sys_id=83064177db3ee850f0e3220805961959) for the latest version of the Luna Key Broker.

| Version | Supported          |
| ------- | ------------------ |
| 1.2.0   | :white_check_mark: |
| < 1.2.0 | :x:                |

## Reporting a Vulnerability & Disclosure policy

Define the procedure for what a reporter who finds a security issue needs to do in order to fully disclose the problem safely, including who to contact and how.

If you find any security issues or vulnerabilities, please open a new security advisory via the GitHub function or mail the maintainer [Martin](mailto:martin.gegenleitner@thalesgroup.com).

As this is mainly a deployment guide, it is not expected that there can be any security vulnerabilities. Please don't expect fast response times as it is a guide for non production use. If you find any issues with the Luna Key Broker software itself, please open a ticket at [Thales support](https://supportportal.thalesgroup.com/).

## Security Update policy

To get notified when new security vulnerabilities are found, please use GitHub's "Watch" feature on "Security alerts". New vulnerabilities will be published in the security advisory section of this repository and updated when solved.

## Security related configuration

The goal of this repository is to give a straight forward guideline on how to deploy the Luna Key Broker in order to showcase it. Please be aware that it is **NOT** the recommended way of deployment. The following things should be changed in order to make it save and secure for production use.

* Do **NOT** deploy the DKE service in the realms of Microsoft as the main goal of DKE is to block Microsoft (and maybe also specific US departments) from accessing your most valuable/sensitive data. So a deployment on Azure Kubernetes Services wouldn't make much sense.
  * Consider an on-premise deployment or a deployment in a non-US cloud provider as a counterpart to your Microsoft environment.
  * Thales also offers full managed DKE service based on its CipherTrust Data Security Platform as a Service offering.
* Adapt the [OPA/rego file](/dke-service/opa_policies.rego) to your needs and use its possibilities of a second policy enforcement point.
* Use own passwords instead of the defaults shown in the guide. Follow instructions on the [official Thales Documentation](https://thalesdocs.com/dpod/services/luna_cloud_hsm/service/guides/luna_cloud_hsm/index.html) on how to setup a cloud based HSM properly.

## Known security gaps & future enhancements

This repository might be behind the latest and recommended versions of the software it uses. If you plan to use the provided guide to create a production environment, please ensure to check your software version selection.
