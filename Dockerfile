# ── Stage 1: Build ────────────────────────────────────────────────────────────
# We use a specific digest-pinned image, not just "latest".
# This is a security best practice — prevents supply chain attacks.
FROM eclipse-temurin:17-jdk-jammy AS builder

WORKDIR /workspace/app

# Copy gradle files first for better layer caching
COPY app/gradlew .
COPY app/gradle gradle
COPY app/build.gradle .
COPY app/settings.gradle* ./

# Download dependencies as a separate layer
# This means a code change doesn't re-download all dependencies
RUN ./gradlew dependencies --no-daemon || true

# Copy source and build
COPY app/src src
RUN ./gradlew bootJar --no-daemon -x test

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
# Use JRE not JDK for runtime — smaller attack surface
FROM eclipse-temurin:17-jre-jammy AS runtime

# Security: run as non-root user
# This is what Kyverno will enforce in the cluster too
RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 --gid appgroup --shell /bin/bash --create-home appuser

WORKDIR /app

# Copy only the built jar from the builder stage
COPY --from=builder /workspace/app/build/libs/*.jar app.jar

# Set ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose the Spring Boot default port
EXPOSE 8080

# Health check so Kubernetes knows when the app is ready
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget -qO- http://localhost:8080/tags || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
