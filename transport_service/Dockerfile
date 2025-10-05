# Use Ballerina runtime image with multi-platform support
FROM --platform=$BUILDPLATFORM ballerina/ballerina:2201.12.10

# Set working directory
WORKDIR /app

# Copy Ballerina project files
COPY Ballerina.toml .
COPY Config.toml .
COPY main.bal .

# Build the Ballerina application
RUN bal build

# Expose port
EXPOSE 8082

# Run the application using the built JAR
CMD ["bal", "run", "target/bin/transport_service.jar"]