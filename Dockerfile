FROM eclipse-temurin:17-jdk-alpine AS build
WORKDIR /workspace/app

# Optimize layer caching by copying only the necessary files to resolve dependencies first
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Download dependencies to take advantage of the cache
RUN chmod +x ./mvnw && ./mvnw dependency:go-offline -B

# Copy the source code and build
COPY src src
RUN ./mvnw package -DskipTests
RUN mkdir -p target/dependency && (cd target/dependency; jar -xf ../*.jar)

FROM eclipse-temurin:17-jre-alpine
VOLUME /tmp
ARG DEPENDENCY=/workspace/app/target/dependency

# Install curl for healthcheck
RUN apk add --no-cache curl

COPY --from=build ${DEPENDENCY}/BOOT-INF/lib /app/lib
COPY --from=build ${DEPENDENCY}/META-INF /app/META-INF
COPY --from=build ${DEPENDENCY}/BOOT-INF/classes /app

# Create non-root user
RUN addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 --ingroup appgroup appuser && \
    chown -R appuser:appgroup /app
USER appuser

EXPOSE 8888
ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./urandom","-cp","app:app/lib/*","com.uguimar.configserver.ConfigServerApplication"]