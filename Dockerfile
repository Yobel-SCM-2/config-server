# Build stage
FROM openjdk:17.0.2-jdk-slim as build

# Install Maven and required tools
RUN apt-get update && apt-get install -y ca-certificates wget maven && \
    rm -rf /var/cache/apt/*

WORKDIR /workspace/app

# Copy Maven configuration files first to leverage Docker cache
COPY pom.xml .

# Download dependencies in a separate layer
RUN mvn dependency:go-offline -B

# Copy the source code and build the project
COPY src src
RUN mvn package -DskipTests

# Extract the JAR contents for the next stage
RUN mkdir -p target/dependency && (cd target/dependency; jar -xf ../*.jar)

# Runtime stage
FROM openjdk:17.0.2-jdk-slim

ARG DEPENDENCY=/workspace/app/target/dependency

# Copy the application layers to optimize Docker caching
COPY --from=build ${DEPENDENCY}/BOOT-INF/lib /app/lib
COPY --from=build ${DEPENDENCY}/META-INF /app/META-INF
COPY --from=build ${DEPENDENCY}/BOOT-INF/classes /app

# Application configuration
EXPOSE 8888
ENV SPRING_PROFILES_ACTIVE=dev

# Start the application
ENTRYPOINT ["java", "-cp", "app:app/lib/*", "com.uguimar.configserver.ConfigServerApplication"]
