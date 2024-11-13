# 빌드 스테이지
FROM eclipse-temurin:17-jdk AS builder

# 작업 디렉토리 설정
WORKDIR /app

# 필요한 패키지 설치
RUN apt-get update && apt-get install -y findutils && rm -rf /var/lib/apt/lists/*

# 소스 코드 복사 (권한 설정 포함)
COPY --chown=1000:1000 . .

# gradlew 실행 권한 부여
RUN chmod +x gradlew

# 의존성 다운로드 및 빌드
RUN ./gradlew build -x test --no-daemon

# 실행 스테이지
FROM eclipse-temurin:17-jre

# 작업 디렉토리 설정
WORKDIR /app

# 빌드된 JAR 파일 복사
COPY --from=builder /app/build/libs/*.jar app.jar

# 포트 설정 (필요한 경우)
EXPOSE 8080

# 애플리케이션 실행
ENTRYPOINT ["java", "-jar", "app.jar"]
