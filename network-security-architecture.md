# Network Security Architecture

This document describes the network security groups (NSGs) and virtual network service endpoints (VNETs) used to restrict inbound and outbound traffic to our Azure infrastructural components.

## Virtual Network (VNET)

- **Name**: myapp-vnet
- **Address Space**: 10.0.0.0/16

### Subnets

1. **App Subnet**
   - Name: app-subnet
   - Address Range: 10.0.1.0/24
   - Service Endpoints: Microsoft.Sql, Microsoft.KeyVault

2. **Database Subnet**
   - Name: db-subnet
   - Address Range: 10.0.2.0/24
   - Service Endpoints: Microsoft.Sql

## Network Security Group (NSG)

- **Name**: app-nsg
- **Associated with**: app-subnet

### Inbound Security Rules

1. **AllowHTTPInbound**
   - Priority: 100
   - Port: 80
   - Protocol: TCP
   - Source: Any
   - Destination: Any

2. **AllowHTTPSInbound**
   - Priority: 110
   - Port: 443
   - Protocol: TCP
   - Source: Any
   - Destination: Any

## Service Endpoints

- App Subnet: Enabled for Microsoft.Sql and Microsoft.KeyVault
- DB Subnet: Enabled for Microsoft.Sql

These endpoints allow resources in these subnets to securely access Azure SQL and Key Vault services over the Azure backbone network.

## PostgreSQL Virtual Network Rule

A rule is created to allow the PostgreSQL server to accept connections from the app-subnet.

## App Service VNet Integration

The App Service is integrated with the app-subnet, allowing it to access resources within the VNET or connected networks.

## Autoscaling

Autoscale settings are configured for the App Service Plan:
- Minimum instances: 1
- Maximum instances: 2
- Scale out: When CPU > 75%
- Scale in: When CPU < 25%

## Security Benefits

- Inbound traffic to the application is restricted to HTTP and HTTPS.
- The database is not directly accessible from the internet, only from the application subnet.
- Service endpoints provide an additional layer of security for accessing Azure services.
- The virtual network isolates the application and database components.

## Areas for Potential Enhancement

- The NSG allows HTTP/HTTPS traffic from any source. This could be restricted to specific IP ranges if needed.
- Outbound rules are not explicitly defined in the NSG, which means all outbound traffic is allowed by default.
- Consider adding a firewall or Azure Application Gateway for additional layer 7 protection.