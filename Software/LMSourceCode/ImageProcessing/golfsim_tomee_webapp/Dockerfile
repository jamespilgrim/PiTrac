# License Compliance Information
# This Dockerfile creates a container that includes:
# - TomEE (Apache License 2.0)
# - OpenJDK (GPL v2 with Classpath Exception)
# - Maven (Apache License 2.0)
# - ActiveMQ (Apache License 2.0)
# See DOCKER-LICENSE-COMPLIANCE.md for full license details

# Use TomEE plume as base image
FROM tomee:10.0.0-M3-plume

# Install OpenJDK and required packages
RUN apt-get update && apt-get install -y \
    openjdk-17-jdk \
    maven \
    && rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Set environment variables
ENV PITRAC_ROOT=/app/PiTrac/Software/LMSourceCode \
    PITRAC_BASE_IMAGE_LOGGING_DIR=/app/LM_Shares/Images/ \
    PITRAC_WEBSERVER_SHARE_DIR=/app/LM_Shares/WebShare/ \
    PITRAC_MSG_BROKER_FULL_ADDRESS=tcp://activemq:61616 \
    MAVEN_OPTS=-Xmx1024M

# Create necessary directories
RUN mkdir -p /app/LM_Shares/Images \
    /app/LM_Shares/WebShare \
    /app/Dev/WebAppDev

# Configure TomEE
COPY conf/tomcat-users.xml /usr/local/tomee/conf/tomcat-users.xml
COPY conf/context.xml /usr/local/tomee/webapps/manager/META-INF/context.xml

# Set up directory structure and files
WORKDIR /app/PiTrac/Software/LMSourceCode/ImageProcessing/golfsim_tomee_webapp
COPY . .

# Create a minimal config file
RUN echo '{ \
    "user_interface": { \
        "kWebServerTomcatShareDirectory": "Images", \
        "kWebServerShareDirectory": "/app/LM_Shares/Images" \
    }, \
    "ipc_interface": { \
        "kWebActiveMQHostAddress": "tcp://activemq:61616" \
    } \
}' > ../golf_sim_config.json

# Convert Windows line endings to Unix and build
WORKDIR /app/Dev/WebAppDev
RUN cp -r /app/PiTrac/Software/LMSourceCode/ImageProcessing/golfsim_tomee_webapp/* . && \
    sed -i 's/\r$//' refresh_from_dev.sh && \
    chmod +x refresh_from_dev.sh && \
    ./refresh_from_dev.sh && \
    mvn package && \
    cp target/golfsim.war /usr/local/tomee/webapps/

# Create volume mount points
VOLUME ["/app/LM_Shares/Images", "/app/LM_Shares/WebShare"]

# Copy license compliance documentation
COPY DOCKER-LICENSE-COMPLIANCE.md /usr/share/doc/

# Expose TomEE ports
EXPOSE 8080
