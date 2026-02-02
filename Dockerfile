FROM eclipse-temurin:25-jre

EXPOSE 8080

WORKDIR /app

COPY target/farm-mapping-0.0.1-SNAPSHOT-exec.jar app.jar
RUN mkdir -p /app/data/photos
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
