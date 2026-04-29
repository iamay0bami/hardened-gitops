# Stage 1: Build 
FROM eclipse-temurin:17-jdk-jammy AS builder

WORKDIR /workspace/app

COPY app/gradlew .
COPY app/gradle gradle
COPY app/build.gradle .
COPY app/settings.gradle* ./

# Fix execute permission on gradlew
RUN chmod +x gradlew

# Download dependencies as a separate layer
RUN ./gradlew dependencies --no-daemon || true

# Copy source and build
COPY app/src src
RUN ./gradlew bootJar --no-daemon -x test

# Stage 2: Runtime 
FROM eclipse-temurin:17-jre-jammy AS runtime

RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 --gid appgroup --shell /bin/bash --create-home appuser

WORKDIR /app

COPY --from=builder /workspace/app/build/libs/*.jar app.jar

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget -qO- http://localhost:8080/tags || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
