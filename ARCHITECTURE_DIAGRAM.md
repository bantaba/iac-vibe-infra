# Azure Bicep Infrastructure Architecture

## High-Level Infrastructure Overview

<div style="width: 100%; height: 800px; border: 1px solid #ccc; overflow: auto; position: relative;">
<div style="transform-origin: 0 0; transition: transform 0.3s ease;" id="diagram-container">

```mermaid
graph TB
    %% Internet and External Access
    Internet([Internet]) --> WAF[Web Application Firewall]
    
    %% DDoS Protection
    DDoS[DDoS Protection Plan] --> WAF
    
    %% Application Gateway Layer
    WAF --> AGW[Application Gateway<br/>SSL Termination<br/>Layer 7 Load Balancing]
    
    %% Public IP
    PIP[Public IP<br/>Standard SKU<br/>Zone Redundant] --> AGW
    
    %% Virtual Network Manager
    VNM[Virtual Network Manager<br/>Centralized Network Governance] -.-> VNET
    
    %% Virtual Network and Subnets
    subgraph VNET[Virtual Network - Hub]
        subgraph AGW_SUBNET[Application Gateway Subnet]
            AGW
        end
        
        subgraph WEB_SUBNET[Web Tier Subnet]
            VMSS_WEB[VM Scale Set - Web<br/>Auto-scaling<br/>Zone Redundant]
        end
        
        subgraph BIZ_SUBNET[Business Tier Subnet]
            ILB_BIZ[Internal Load Balancer<br/>Business Tier]
            VMSS_BIZ[VM Scale Set - Business<br/>Auto-scaling<br/>Zone Redundant]
        end
        
        subgraph DATA_SUBNET[Data Tier Subnet]
            ILB_DATA[Internal Load Balancer<br/>Data Tier]
            SQL[Azure SQL Database<br/>TDE Enabled<br/>Advanced Security]
            STORAGE[Storage Account<br/>Private Endpoints<br/>Encryption at Rest]
        end
        
        subgraph MGMT_SUBNET[Management Subnet]
            BASTION[Azure Bastion<br/>Secure Access]
        end
    end
    
    %% Network Security Groups
    NSG_WEB[NSG - Web Tier] --> WEB_SUBNET
    NSG_BIZ[NSG - Business Tier] --> BIZ_SUBNET
    NSG_DATA[NSG - Data Tier] --> DATA_SUBNET
    NSG_MGMT[NSG - Management] --> MGMT_SUBNET
    
    %% Traffic Flow
    AGW --> VMSS_WEB
    VMSS_WEB --> ILB_BIZ
    ILB_BIZ --> VMSS_BIZ
    VMSS_BIZ --> ILB_DATA
    ILB_DATA --> SQL
    VMSS_BIZ --> STORAGE
    
    %% Security and Identity
    subgraph SECURITY[Security & Identity Layer]
        KV[Key Vault<br/>Secrets & Certificates<br/>RBAC Enabled]
        MI[Managed Identities<br/>5 User-Assigned<br/>Service Authentication]
        AAD[Azure Active Directory<br/>Identity Management]
    end
    
    %% Private Endpoints
    PE_SQL[Private Endpoint<br/>SQL Database] --> SQL
    PE_STORAGE[Private Endpoint<br/>Storage Account] --> STORAGE
    PE_KV[Private Endpoint<br/>Key Vault] --> KV
    
    %% Monitoring and Logging
    subgraph MONITORING[Monitoring & Logging]
        LAW[Log Analytics Workspace<br/>Centralized Logging]
        AI[Application Insights<br/>APM & Telemetry]
        ALERTS[Azure Monitor Alerts<br/>Proactive Monitoring]
    end
    
    %% Managed Identity Connections
    MI -.-> KV
    MI -.-> SQL
    MI -.-> STORAGE
    AGW -.-> MI
    VMSS_WEB -.-> MI
    VMSS_BIZ -.-> MI
    
    %% Monitoring Connections
    VMSS_WEB --> LAW
    VMSS_BIZ --> LAW
    SQL --> LAW
    STORAGE --> LAW
    AGW --> LAW
    
    VMSS_WEB --> AI
    VMSS_BIZ --> AI
    
    LAW --> ALERTS
    AI --> ALERTS
    
    %% Styling
    classDef internetClass fill:#ff6b6b,stroke:#d63031,stroke-width:2px,color:#fff
    classDef securityClass fill:#74b9ff,stroke:#0984e3,stroke-width:2px,color:#fff
    classDef computeClass fill:#55a3ff,stroke:#2d3436,stroke-width:2px,color:#fff
    classDef dataClass fill:#fd79a8,stroke:#e84393,stroke-width:2px,color:#fff
    classDef networkClass fill:#00b894,stroke:#00a085,stroke-width:2px,color:#fff
    classDef monitorClass fill:#fdcb6e,stroke:#e17055,stroke-width:2px,color:#fff
    
    class Internet,WAF,DDoS internetClass
    class KV,MI,AAD,PE_SQL,PE_STORAGE,PE_KV securityClass
    class AGW,VMSS_WEB,VMSS_BIZ,ILB_BIZ,ILB_DATA,BASTION computeClass
    class SQL,STORAGE dataClass
    class VNET,VNM,PIP,NSG_WEB,NSG_BIZ,NSG_DATA,NSG_MGMT networkClass
    class LAW,AI,ALERTS monitorClass
```

</div>

<!-- Zoom Controls -->
<div style="position: absolute; top: 10px; right: 10px; z-index: 1000; background: white; padding: 10px; border-radius: 5px; box-shadow: 0 2px 5px rgba(0,0,0,0.2);">
  <button onclick="zoomIn()" style="margin: 2px; padding: 5px 10px; cursor: pointer;">🔍 Zoom In</button>
  <button onclick="zoomOut()" style="margin: 2px; padding: 5px 10px; cursor: pointer;">🔍 Zoom Out</button>
  <button onclick="resetZoom()" style="margin: 2px; padding: 5px 10px; cursor: pointer;">↻ Reset</button>
</div>

</div>

<script>
let currentZoom = 1;
const zoomStep = 0.2;
const minZoom = 0.5;
const maxZoom = 3;

function zoomIn() {
    if (currentZoom < maxZoom) {
        currentZoom += zoomStep;
        applyZoom();
    }
}

function zoomOut() {
    if (currentZoom > minZoom) {
        currentZoom -= zoomStep;
        applyZoom();
    }
}

function resetZoom() {
    currentZoom = 1;
    applyZoom();
}

function applyZoom() {
    const container = document.getElementById('diagram-container');
    if (container) {
        container.style.transform = `scale(${currentZoom})`;
    }
}

// Mouse wheel zoom
document.addEventListener('wheel', function(e) {
    if (e.ctrlKey || e.metaKey) {
        e.preventDefault();
        if (e.deltaY < 0) {
            zoomIn();
        } else {
            zoomOut();
        }
    }
});
</script>

## Architecture Layers

### 🌐 **Internet & Edge Layer**
- **DDoS Protection**: Enterprise-grade attack mitigation
- **Web Application Firewall**: OWASP rule set protection
- **Application Gateway**: SSL termination and Layer 7 load balancing
- **Public IP**: Standard SKU with zone redundancy

### 🔒 **Security & Identity Layer**
- **Azure Key Vault**: Centralized secrets and certificate management
- **Managed Identities**: 5 user-assigned identities for service authentication
- **Azure Active Directory**: Identity and access management
- **Private Endpoints**: Secure connectivity to PaaS services

### 💻 **Compute Layer**
- **VM Scale Sets**: Auto-scaling compute across availability zones
- **Load Balancers**: Internal traffic distribution for business and data tiers
- **Availability Sets**: Fault domain distribution (non-zone deployments)

### 🗄️ **Data Layer**
- **Azure SQL Database**: Managed database with TDE and Advanced Security
- **Storage Account**: Blob storage with encryption and lifecycle management
- **Private Connectivity**: All data services accessible via private endpoints

### 🌐 **Network Layer**
- **Virtual Network Manager**: Centralized network governance
- **Network Security Groups**: Subnet-level firewall rules
- **Hub-Spoke Topology**: Scalable network architecture
- **Zone Redundancy**: High availability across availability zones

### 📊 **Monitoring Layer**
- **Log Analytics Workspace**: Centralized logging and analytics
- **Application Insights**: Application performance monitoring
- **Azure Monitor Alerts**: Proactive alerting and notifications

## Key Security Features

### 🔐 **Defense in Depth**
1. **Perimeter Security**: WAF + DDoS Protection
2. **Network Security**: NSGs + Private Endpoints
3. **Identity Security**: Managed Identities + RBAC
4. **Data Security**: TDE + Encryption at Rest
5. **Monitoring**: Comprehensive logging and alerting

### 🎯 **Zero Trust Architecture**
- No implicit trust between services
- All communication authenticated via managed identities
- Private endpoints for all PaaS services
- Least privilege access controls

### 📈 **High Availability & Scalability**
- Multi-zone deployment across 3 availability zones
- Auto-scaling VM scale sets
- Zone-redundant load balancers and public IPs
- Geo-redundant storage and database backups

## Deployment Environments

The infrastructure supports three environments with different configurations:

| Feature | Development | Staging | Production |
|---------|-------------|---------|------------|
| **Zones** | Single Zone | 2 Zones | 3 Zones |
| **Auto-scaling** | Disabled | Limited | Full |
| **Private Endpoints** | Optional | Enabled | Enabled |
| **DDoS Protection** | Disabled | Enabled | Enabled |
| **Backup Retention** | 7 days | 30 days | 90 days |
| **Log Retention** | 30 days | 90 days | 365 days |
