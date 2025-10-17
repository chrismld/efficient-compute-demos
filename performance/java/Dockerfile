FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /app/target/json-processor-1.0.0.jar app.jar

# Install async-profiler
RUN apt-get update && \
    apt-get install -y wget && \
    wget https://github.com/async-profiler/async-profiler/releases/download/v3.0/async-profiler-3.0-linux-x64.tar.gz && \
    tar -xzf async-profiler-3.0-linux-x64.tar.gz -C /opt && \
    rm async-profiler-3.0-linux-x64.tar.gz && \
    rm -rf /var/lib/apt/lists/*

ENV PORT=8080
ENV JAVA_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints -XX:+PreserveFramePointer"

EXPOSE 8080

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]