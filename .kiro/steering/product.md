# Product Overview

This is an Azure Bicep Infrastructure as Code (IaC) project that implements a secure, multi-tier application architecture using Azure Virtual Network Manager. The solution provides a modularized, enterprise-ready infrastructure template for deploying scalable web applications with defense-in-depth security practices.

## Key Features

- **Modular Architecture**: Reusable Bicep modules for networking, security, compute, and data components
- **Multi-Environment Support**: Separate configurations for development, staging, and production environments
- **Security-First Design**: Implements defense-in-depth with WAF, NSGs, private endpoints, and centralized secret management
- **Automated Security Scanning**: Integrated Checkov scanning for continuous security validation and compliance
- **High Availability**: Multi-zone deployment with load balancing and automated failover
- **Centralized Management**: Uses Azure Virtual Network Manager for unified network governance across environments

## Target Use Cases

- Enterprise web applications requiring secure, scalable infrastructure
- Multi-tier applications with separate web, business, and data layers
- Organizations needing standardized, compliant infrastructure deployments
- Teams adopting Infrastructure as Code practices with Azure Bicep