# Docker Container License Compliance

> **Important**: For guidance on deployment and distribution requirements, please see [DEPLOYMENT.md](./DEPLOYMENT.md).

## Base Image
- TomEE (10.0.0-M3-plume): Apache License 2.0
  - Includes Apache Tomcat: Apache License 2.0
  - Source: https://github.com/apache/tomee
  - Tomcat Source: https://github.com/apache/tomcat
  - TomEE includes additional JavaEE components, each under Apache License 2.0

## Installed Packages
- OpenJDK 17: GPL v2 with Classpath Exception
- Maven: Apache License 2.0
- ActiveMQ: Apache License 2.0
- Jackson JSON Processor: Apache License 2.0
  - Jackson Core
  - Jackson Databind
  - Jackson YAML (Log4j2 configuration)

## Project Licenses
This container includes components covered by the following licenses:
1. Main Project License
2. ED_LIB License
3. RPICAM-APPS License
4. SHEDSKIN License
5. Verdant Contributor License Agreement

## Compliance Notes
1. Source code availability:
   ⚠️ **NO MODIFICATIONS TO GPL COMPONENTS ARE PERMITTED**
   - This project uses GPL components strictly as-is
   - No modifications to GPL-licensed code are allowed
   - Build instructions are provided in README.md
   - Source code for GPL components is available from their original sources

2. License notices:
   - Full license texts are included in development container
   - Attribution notices are preserved in source code

3. Third-party components:
   - All dependencies are tracked in pom.xml
   - License information is preserved

## Distribution Requirements
⚠️ **IMPORTANT: DO NOT DISTRIBUTE DOCKER CONTAINERS**
The Docker configuration and containers in this repository are for **development purposes only** and must not be distributed to end users. See [DEPLOYMENT.md](./DEPLOYMENT.md) for proper distribution requirements.

For proper application distribution:
1. Follow the distribution package structure in DEPLOYMENT.md
2. Include all compliance documentation
3. Maintain all license and attribution notices
3. Provide access to source code for GPL components
4. Include copies of all relevant licenses
