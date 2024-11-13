FROM openjdk:17 AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y findutils

COPY gradlew .
COPY gradle gradle
COPY build.gradle.kts .
COPY settings.gradle.kts .

RUN chmod +x gradlew

RUN ./gradlew dependencies --no-daemon

COPY src src

RUN ./gradlew build --no-daemon

FROM openjdk:17

WORKDIR /app

COPY --from=builder /app/build/libs/*.jar app.jar

CMD ["java", "-jar", "app.jar"]
