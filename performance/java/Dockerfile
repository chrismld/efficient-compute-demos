FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

FROM eclipse-temurin:17-jdk-jammy
WORKDIR /app

RUN apt-get update && apt-get install -y wget tar gzip procps

RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
       ASYNC_PROFILER_URL="https://github.com/async-profiler/async-profiler/releases/download/v3.0/async-profiler-3.0-linux-x64.tar.gz"; \
    elif [ "$ARCH" = "aarch64" ]; then \
       ASYNC_PROFILER_URL="https://github.com/async-profiler/async-profiler/releases/download/v3.0/async-profiler-3.0-linux-arm64.tar.gz"; \
    else \
       echo "Unsupported architecture: $ARCH" && exit 1; \
    fi && \
    wget -q $ASYNC_PROFILER_URL && \
    mkdir /async-profiler && \
    tar -xvzf $(basename $ASYNC_PROFILER_URL) -C /async-profiler --strip-components=1 && \
    rm $(basename $ASYNC_PROFILER_URL) && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /app/target/json-processor-1.0.0.jar /app/app.jar

ENV JAVA_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints -XX:+PreserveFramePointer"

ENV PATH="/async-profiler/bin:$PATH"

EXPOSE 8080

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]