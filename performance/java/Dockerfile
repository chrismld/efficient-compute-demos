FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

FROM eclipse-temurin:17-jdk-jammy
WORKDIR /app
COPY --from=build /app/target/json-processor-1.0.0.jar app.jar

# Install perf and async-profiler
RUN apt-get update && \
    apt-get install -y linux-tools-generic wget && \
    # Create symlink for perf (Ubuntu-specific)
    ln -sf /usr/lib/linux-tools/*/perf /usr/bin/perf || true && \
    # Install async-profiler
    wget -q https://github.com/async-profiler/async-profiler/releases/download/v3.0/async-profiler-3.0-linux-x64.tar.gz && \
    tar -xzf async-profiler-3.0-linux-x64.tar.gz -C /opt && \
    rm async-profiler-3.0-linux-x64.tar.gz && \
    rm -rf /var/lib/apt/lists/*

ENV PORT=8080

ENV JAVA_OPTS="-XX:+UnlockDiagnosticVMOptions \
-XX:+DebugNonSafepoints \
-XX:+PreserveFramePointer \
-Xms2g \
-Xmx2g"

ENV PATH="/opt/async-profiler-3.0-linux-x64/bin:${PATH}"

EXPOSE 8080

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
