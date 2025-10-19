# Build stage
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# Runtime image with JDK and async-profiler
FROM eclipse-temurin:17-jdk-jammy
WORKDIR /app

# Install required tools + async-profiler
RUN apt-get update && \
    apt-get install -y wget tar gzip procps && \
    wget -q https://github.com/async-profiler/async-profiler/releases/download/v3.0/async-profiler-3.0-linux-x64.tar.gz && \
    mkdir /async-profiler && \
    tar -xvzf async-profiler-3.0-linux-x64.tar.gz -C /async-profiler --strip-components=1 && \
    rm async-profiler-3.0-linux-x64.tar.gz && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /app/target/json-processor-1.0.0.jar /app/app.jar

# Set environment for JVM to expose proper debug info for async-profiler
ENV JAVA_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints -XX:+PreserveFramePointer"

# Add async-profiler to path for aperf detection
ENV PATH="/async-profiler/bin:$PATH"

EXPOSE 8080
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]