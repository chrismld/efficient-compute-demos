FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /app/target/json-processor-1.0.0.jar app.jar

ENV PORT=8080
# JVM flags for better profiling with aperf
# -XX:+PreserveFramePointer: Essential for accurate stack traces
# -XX:+UnlockDiagnosticVMOptions: Enable diagnostic options
# -XX:+DebugNonSafepoints: More accurate profiling data
ENV JAVA_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints -XX:+PreserveFramePointer"

EXPOSE 8080

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
