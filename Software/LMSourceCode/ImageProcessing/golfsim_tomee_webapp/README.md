# PiTrac TomEE WebApp - Docker Quick Start Guide

> **IMPORTANT**: This Docker configuration is intended for development and testing purposes only. 
> It is not intended for redistribution or production deployment to end users.
> For production deployment requirements, please refer to the main project documentation.

This guide helps you quickly set up the PiTrac TomEE WebApp development environment using Docker. The containerized setup includes both ActiveMQ and TomEE services.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- Git
- 4GB RAM minimum (8GB recommended)

## Quick Start

1. Clone the repository and navigate to the webapp directory:
```powershell
git clone <repository-url>
cd PiTrac/Software/LMSourceCode/ImageProcessing/golfsim_tomee_webapp
```

2. Start the containers in detached mode:
```powershell
docker-compose up --build -d
```

You can view the logs at any time with:
```powershell
docker-compose logs -f
```

3. Access the services:
- PiTrac GUI: http://localhost:8080/golfsim/
- ActiveMQ Console: http://localhost:8161/admin (credentials: admin/admin)
- TomEE Manager: http://localhost:8080/manager/html (credentials: tomcat/tomcat)

## Container Architecture

The setup consists of two main services:

### 1. ActiveMQ Service
- Version: 6.1.4
- Ports:
  - 61616: ActiveMQ broker port
  - 8161: Web console port
- Persistent volume for message data
- Default credentials: admin/admin

### 2. TomEE Service
- Version: 10.0.0-M3 (Plume distribution with JMS support)
- Port: 8080
- Includes:
  - Maven build environment
  - Deployed PiTrac webapp
  - Shared volumes for Images and WebShare
  - Jackson JSON Processor (for configuration and logging)
- Default credentials: tomcat/tomcat

## Development Workflow

### Starting Development
```powershell
# Start in detached mode
docker-compose up -d

# View logs
docker-compose logs -f
```

### Rebuilding After Changes
```powershell
# Rebuild and restart services
docker-compose down
docker-compose up --build
```

### Stopping Services
```powershell
# Stop all services
docker-compose down

# Stop and remove volumes (careful - this erases persistent data!)
docker-compose down -v
```

## Volume Locations

The setup includes three persistent volumes:
1. `activemq_data`: ActiveMQ message data and configuration
2. `images_share`: PiTrac image storage
3. `web_share`: Web-accessible shared files

## Environment Variables

Key environment variables set in the containers:
- `PITRAC_ROOT`: /app/PiTrac/Software/LMSourceCode
- `PITRAC_BASE_IMAGE_LOGGING_DIR`: /app/LM_Shares/Images/
- `PITRAC_WEBSERVER_SHARE_DIR`: /app/LM_Shares/WebShare/
- `PITRAC_MSG_BROKER_FULL_ADDRESS`: tcp://activemq:61616

## Troubleshooting

### Common Issues

1. Port Conflicts
```powershell
# Check if ports are in use
Get-NetTCPConnection -LocalPort 8080, 8161, 61616 | Select-Object LocalPort, State, OwningProcess

# Find process using a port
Get-Process -Id <OwningProcess>
```

2. Container Won't Start
```powershell
# View detailed logs
docker-compose logs --tail=100 tomee
docker-compose logs --tail=100 activemq
```

3. Connection Issues
```powershell
# Check if containers are running
docker ps

# Check container network
docker network ls
docker network inspect pitrac_net
```

### Maintenance

Clean up unused Docker resources:
```powershell
# Remove unused containers
docker container prune

# Remove unused volumes
docker volume prune

# Remove unused images
docker image prune
```

## Security Notes

- Default credentials are for development only
- For production:
  1. Change all default passwords
  2. Enable HTTPS
  3. Configure proper access controls
  4. Review and restrict network access

## Additional Resources

- [ActiveMQ Documentation](https://activemq.apache.org/components/classic/documentation)
- [TomEE Documentation](https://tomee.apache.org/docs/)
- [Docker Documentation](https://docs.docker.com/)
