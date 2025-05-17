# PiTrac Deployment Guide

## Development vs. Distribution - Important Legal Distinctions

### Development Environment (Docker)
The Docker configuration in this repository is for **development purposes only**. When used for development:
- Running containers locally for development
- Using containers in CI/CD pipelines
- Testing in your own infrastructure
- Internal deployment for development teams

This usage does NOT constitute "distribution" under the terms of GPL and other licenses, as the containers remain under direct control of the development team.

### Distribution to End Users
When providing PiTrac to end users, DO NOT distribute the Docker development environment. Instead:

1. **Proper Distribution Method**
   - Package the compiled application without development dependencies
   - Include only runtime dependencies
   - Follow all license requirements for redistributed components

2. **Components That Must Not Be Redistributed**
   - Docker development environment
   - Build tools (Maven)
   - Development-time dependencies
   - Test frameworks and tools

3. **Required for Distribution**
   - Runtime JRE (not full JDK)
   - ActiveMQ runtime (not development version)
   - Application WAR file
   - Configuration files
   - License documentation

## Compliance Requirements

### For Development (Docker Environment)
- Keep Docker configuration internal
- Use only for development and testing
- Do not distribute container images to end users
- Document development dependencies

### For Distribution
1. **License Compliance**
   - Include all required license notices
   - Provide access to source code
   - Include third-party attributions
   - Document any modifications to GPL components

2. **Runtime Components**
   - Use properly licensed runtime versions
   - Include only necessary dependencies
   - Document all included third-party software

3. **Documentation Requirements**
   - Installation instructions
   - Configuration guide
   - License information
   - Attribution notices

## Distribution Package Structure
```
pitrac-distribution/
├── runtime/
│   ├── jre/              # Runtime only, not full JDK
│   └── activemq/         # Runtime configuration
├── webapp/
│   └── golfsim.war       # Application only
├── config/
│   └── golf_sim_config.json
├── docs/
│   ├── LICENSE
│   ├── THIRDPARTY.txt    # Third-party license notices
│   └── README.md
└── INSTALL.txt
```

## License Requirements for Distribution

### License File Organization
All license files must be included in the distribution package under the `docs/licenses/` directory:
- Full license texts
- Attribution notices
- Third-party license documentation
- Modification notices (if applicable)
- Source code availability statements

### Component-Specific Requirements

1. **OpenJDK Runtime**
   - Include GPL v2 with Classpath Exception notice
   - Document version and source availability

2. **ActiveMQ Runtime**
   - Include Apache License 2.0
   - Document version and configuration

3. **Application Server Runtime**
   - Apache TomEE: Apache License 2.0
   - Apache Tomcat (included in TomEE): Apache License 2.0
   - Document versions used
   - Include attribution for all bundled JavaEE components
   - Preserve all NOTICE files

4. **Application Code**
   - Include project license
   - Document any third-party components
   - Provide required attributions
   
5. **JSON Processing Runtime**
   - Jackson Core: Apache License 2.0
   - Jackson Databind: Apache License 2.0
   - Jackson YAML: Apache License 2.0
   - Document versions used

## Creating a Distribution Package

1. **Build Process and Distribution Separation**
   
   The distribution package must be created in a separate location from the source code:
   - Ensures no development dependencies are accidentally included
   - Maintains clean separation between development and runtime environments
   - Simplifies license compliance verification
   - Makes it easier to validate included components
   - Prevents distribution of internal development tools and configurations

   The build team will provide specific procedures for creating compliant distribution packages.

2. **Validation**
   - Verify all required licenses are included
   - Check runtime dependencies
   - Validate configuration
   - Test installation process

## Security Considerations

1. **Runtime Configuration**
   - Remove development credentials
   - Configure secure defaults
   - Document security settings

2. **Access Control**
   - Configure proper permissions
   - Document security requirements
   - Remove development tools

## Version Control and Release Process
1. **Release Tagging**
   - Create git tags for each release version
   - Document all changes in CHANGELOG.md
   - Update version numbers in:
     - pom.xml
     - Documentation files
     - Distribution package

2. **Pre-Release Checklist**
   - Review and update license compliance
   - Test all deployment scenarios
   - Update documentation
   - Sign release artifacts

3. **Distribution Package Verification**
   - Ensure all required components are present
   - Verify file permissions and ownership
   - Test installation process
   - Validate runtime configurations

## Testing and Verification Procedures

1. **Development Environment Testing**
   ```bash
   # Start development environment
   docker-compose up -d
   
   # Verify services
   docker-compose ps
   docker logs golfsim_tomee_webapp-tomee-1
   
   # Test ActiveMQ connection
   curl http://localhost:8080/golfsim/testmonitor
   ```

2. **Distribution Package Testing**
   - Install in clean environment
   - Verify all components start correctly
   - Test application functionality
   - Validate license compliance
   - Check security configurations

3. **Integration Testing**
   - Test ActiveMQ connectivity
   - Verify database operations
   - Check logging functionality
   - Test error handling
   - Validate backup procedures

## Additional Resources
- Link to full license documentation
- Runtime configuration guide
- Security documentation
- Installation verification procedures
