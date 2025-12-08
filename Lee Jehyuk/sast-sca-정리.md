# SAST/SCA 파이프라인 정리

## 개요
GitHub → CodeBuild → SAST(SonarCloud) + SCA(Snyk) → S3 저장 → ECS 배포

## 아키텍처

```
GitHub (WebGoat)
    ↓ (Push/PR)
CodeBuild Webhook 트리거
    ↓
buildspec.yml 실행
    ├─ install: 도구 설치
    ├─ pre_build: SAST + SCA 스캔
    ├─ build: Container 스캔
    └─ post_build: 결과 저장 + 배포
```

## 1. GitHub 저장소

- **저장소**: `Start-Cloud-Team/WebGoat`
- **buildspec.yml 위치**: 루트 디렉토리
- **트리거**: Push 또는 Pull Request

## 2. CodeBuild 프로젝트

### 프로젝트 정보
- **프로젝트명**: `bWAPP-CodeBuild`
- **리전**: `ap-northeast-2`
- **소스**: GitHub (Webhook 연결)
- **빌드 환경**: 
  - 이미지: `aws/codebuild/standard:7.0`
  - 컴퓨팅: `BUILD_GENERAL1_MEDIUM`
  - Privileged Mode: 활성화 (Docker 사용)

### Webhook 설정
```
URL: https://api.github.com/repos/Start-Cloud-Team/WebGoat/hooks/581533738
트리거: Push, Pull Request
```

## 3. buildspec.yml 구조

### 환경 변수
```yaml
env:
  variables:
    IMAGE_REPO_NAME: "bwapp-image-repo"
    IMAGE_TAG: "latest"
    ACCOUNT_ID: "329984431650"
    AWS_DEFAULT_REGION: "ap-northeast-2"
    S3_BUCKET: "devops-security-scan-results"
  parameter-store:
    SONAR_TOKEN: /devops/sonarcloud/token
    SNYK_TOKEN: /devops/snyk/token
```

### Phase 1: Install (도구 설치)

```bash
# Java 런타임
runtime-versions:
  java: corretto21

# SonarScanner 설치
wget -q https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-6.2.1.4610-linux-x64.zip
unzip -q sonar-scanner-cli-6.2.1.4610-linux-x64.zip

# Snyk CLI 설치
curl -Lo snyk https://static.snyk.io/cli/latest/snyk-linux
chmod +x snyk
mv snyk /usr/local/bin/snyk

# ECR 로그인
aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
```

### Phase 2: Pre_build (SAST + SCA)

#### Maven 빌드
```bash
mvn clean compile -DskipTests -Dmaven.compiler.release=21
```

#### SAST - SonarCloud 스캔
```bash
./sonar-scanner-6.2.1.4610-linux-x64/bin/sonar-scanner \
  -Dsonar.projectKey=Start-Cloud-Team_WebGoat \
  -Dsonar.organization=start-cloud-team \
  -Dsonar.sources=src/main/java \
  -Dsonar.java.binaries=target/classes \
  -Dsonar.branch.name=main \
  -Dsonar.host.url=https://sonarcloud.io \
  -Dsonar.token=$SONAR_TOKEN
```

**검사 항목:**
- 코드 품질 (Code Smells)
- 보안 취약점 (Vulnerabilities)
- 버그 (Bugs)
- 보안 핫스팟 (Security Hotspots)
- 코드 커버리지 (Coverage)

#### SCA - Snyk 스캔
```bash
# Snyk 인증
snyk auth $SNYK_TOKEN

# 의존성 취약점 스캔
snyk test --all-projects --json-file-output=snyk-sca-results.json

# Snyk 대시보드에 업로드
snyk monitor --project-name=bWAPP-SCA
```

**검사 항목:**
- 오픈소스 라이브러리 취약점
- 라이선스 이슈
- 의존성 버전 문제

#### Docker 이미지 Pull
```bash
docker pull webgoat/webgoat:latest
```

### Phase 3: Build (Container 스캔)

```bash
# ECR용 이미지 태깅
docker tag webgoat/webgoat:latest $ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG

# 컨테이너 이미지 취약점 스캔
snyk container test $ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG \
  --json-file-output=snyk-container-results.json

# Snyk 대시보드에 업로드
snyk container monitor $ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG \
  --project-name=bWAPP-Container
```

**검사 항목:**
- 베이스 이미지 취약점
- OS 패키지 취약점
- 애플리케이션 의존성 취약점

### Phase 4: Post_build (결과 저장 + 배포)

#### ECR에 이미지 Push
```bash
docker push $ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG
```

#### SonarCloud 결과 가져오기
```bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# 이슈 목록
curl -u $SONAR_TOKEN: \
  "https://sonarcloud.io/api/issues/search?componentKeys=Start-Cloud-Team_WebGoat&resolved=false" \
  -o sonarcloud-issues.json

# 메트릭 정보
curl -u $SONAR_TOKEN: \
  "https://sonarcloud.io/api/measures/component?component=Start-Cloud-Team_WebGoat&metricKeys=bugs,vulnerabilities,code_smells,coverage,security_hotspots" \
  -o sonarcloud-metrics.json
```

#### S3에 스캔 결과 업로드
```bash
# Snyk SCA 결과
aws s3 cp snyk-sca-results.json s3://$S3_BUCKET/snyk/sca-$TIMESTAMP.json

# Snyk Container 결과
aws s3 cp snyk-container-results.json s3://$S3_BUCKET/snyk/container-$TIMESTAMP.json

# SonarCloud 이슈
aws s3 cp sonarcloud-issues.json s3://$S3_BUCKET/sonarqube/issues-$TIMESTAMP.json

# SonarCloud 메트릭
aws s3 cp sonarcloud-metrics.json s3://$S3_BUCKET/sonarqube/metrics-$TIMESTAMP.json
```

#### ECS 배포 파일 생성
```bash
# imageDetail.json
printf '[{"name":"Bwapp-container","imageUri":"%s"}]' \
  "$ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG" \
  > imageDetail.json

# taskdef.json (ECS Task Definition)
# appspec.yml (CodeDeploy 설정)
```

## 4. 스캔 도구 상세

### SAST - SonarCloud

**목적**: 소스 코드 정적 분석

**URL**: https://sonarcloud.io/project/overview?id=Start-Cloud-Team_WebGoat

**검사 내용:**
- **Bugs**: 코드 오류
- **Vulnerabilities**: 보안 취약점
- **Code Smells**: 코드 품질 이슈
- **Security Hotspots**: 보안 검토 필요 지점
- **Coverage**: 테스트 커버리지

**토큰 위치**: SSM Parameter Store `/devops/sonarcloud/token`

### SCA - Snyk

**목적**: 오픈소스 의존성 취약점 분석

**URL**: https://app.snyk.io

**검사 내용:**
- **SCA (Software Composition Analysis)**
  - 오픈소스 라이브러리 취약점
  - 라이선스 이슈
  - 의존성 버전 문제
  
- **Container Scan**
  - 베이스 이미지 취약점
  - OS 패키지 취약점
  - 애플리케이션 의존성

**프로젝트:**
- `bWAPP-SCA`: 소스 코드 의존성
- `bWAPP-Container`: 컨테이너 이미지

**토큰 위치**: SSM Parameter Store `/devops/snyk/token`

## 5. 결과 저장 위치

### S3 버킷
- **버킷명**: `devops-security-scan-results`
- **리전**: `ap-northeast-2`

### 디렉토리 구조
```
s3://devops-security-scan-results/
├── snyk/
│   ├── sca-YYYYMMDD-HHMMSS.json          # SCA 스캔 결과
│   └── container-YYYYMMDD-HHMMSS.json    # Container 스캔 결과
└── sonarqube/
    ├── issues-YYYYMMDD-HHMMSS.json       # 이슈 목록
    └── metrics-YYYYMMDD-HHMMSS.json      # 메트릭 정보
```

### 최근 스캔 결과 확인
```bash
# Snyk 결과
aws s3 ls s3://devops-security-scan-results/snyk/ --recursive | tail -5

# SonarCloud 결과
aws s3 ls s3://devops-security-scan-results/sonarqube/ --recursive | tail -5
```

## 6. 실행 방법

### 자동 실행 (권장)
GitHub에 코드 Push 또는 Pull Request 생성 시 자동으로 실행됩니다.

```bash
git add .
git commit -m "Update code"
git push origin main
```

### 수동 실행
```bash
# CodeBuild 프로젝트 수동 시작
aws codebuild start-build \
  --project-name bWAPP-CodeBuild \
  --region ap-northeast-2
```

### 빌드 상태 확인
```bash
# 최근 빌드 목록
aws codebuild list-builds-for-project \
  --project-name bWAPP-CodeBuild \
  --region ap-northeast-2 \
  --max-items 5

# 특정 빌드 상세 정보
aws codebuild batch-get-builds \
  --ids "BUILD_ID" \
  --region ap-northeast-2
```

## 7. 빌드 로그 확인

### CloudWatch Logs
```bash
# 로그 그룹
/aws/codebuild/bWAPP-CodeBuild

# 로그 확인
aws logs tail /aws/codebuild/bWAPP-CodeBuild \
  --follow \
  --region ap-northeast-2
```

### AWS 콘솔
1. CodeBuild → Build projects → bWAPP-CodeBuild
2. Build history → 최근 빌드 선택
3. Build logs 탭에서 실시간 로그 확인

## 8. 스캔 결과 확인 방법

### SonarCloud 대시보드
1. https://sonarcloud.io 접속
2. 프로젝트: `Start-Cloud-Team_WebGoat`
3. Overview 탭에서 전체 요약 확인
4. Issues 탭에서 상세 이슈 확인

### Snyk 대시보드
1. https://app.snyk.io 접속
2. 프로젝트 목록:
   - `bWAPP-SCA`: 의존성 취약점
   - `bWAPP-Container`: 컨테이너 취약점
3. 각 프로젝트 클릭하여 상세 정보 확인

### S3에서 JSON 결과 다운로드
```bash
# 최신 Snyk SCA 결과
aws s3 cp s3://devops-security-scan-results/snyk/sca-20251206-203232.json ./

# 최신 SonarCloud 메트릭
aws s3 cp s3://devops-security-scan-results/sonarqube/metrics-20251206-203232.json ./

# JSON 파일 확인
cat sca-20251206-203232.json | jq .
```

## 9. 토큰 관리

### SSM Parameter Store에 저장된 토큰

#### SonarCloud 토큰
```bash
# 토큰 확인 (암호화되어 있음)
aws ssm get-parameter \
  --name /devops/sonarcloud/token \
  --with-decryption \
  --region ap-northeast-2

# 토큰 업데이트
aws ssm put-parameter \
  --name /devops/sonarcloud/token \
  --value "NEW_TOKEN" \
  --type SecureString \
  --overwrite \
  --region ap-northeast-2
```

#### Snyk 토큰
```bash
# 토큰 확인
aws ssm get-parameter \
  --name /devops/snyk/token \
  --with-decryption \
  --region ap-northeast-2

# 토큰 업데이트
aws ssm put-parameter \
  --name /devops/snyk/token \
  --value "NEW_TOKEN" \
  --type SecureString \
  --overwrite \
  --region ap-northeast-2
```

### 토큰 생성 방법

#### SonarCloud 토큰
1. https://sonarcloud.io 로그인
2. My Account → Security
3. Generate Tokens
4. 토큰 이름 입력 → Generate
5. 생성된 토큰을 SSM에 저장

#### Snyk 토큰
1. https://app.snyk.io 로그인
2. Account Settings → General
3. Auth Token 섹션에서 토큰 확인
4. 토큰을 SSM에 저장

## 10. 트러블슈팅

### 빌드 실패 시

#### 1. 로그 확인
```bash
aws logs tail /aws/codebuild/bWAPP-CodeBuild --region ap-northeast-2
```

#### 2. 일반적인 문제

**SonarCloud 스캔 실패**
- 토큰 만료: SSM에서 토큰 업데이트
- 프로젝트 키 오류: buildspec.yml의 projectKey 확인
- 네트워크 문제: `|| true`로 non-blocking 처리됨

**Snyk 스캔 실패**
- 토큰 만료: SSM에서 토큰 업데이트
- CLI 버전 문제: buildspec.yml의 Snyk CLI 다운로드 URL 확인
- 의존성 문제: `|| true`로 non-blocking 처리됨

**Docker 이미지 Pull 실패**
- ECR 로그인 확인
- 이미지 이름/태그 확인
- IAM 권한 확인

#### 3. 권한 문제
CodeBuild 서비스 역할에 필요한 권한:
- ECR: 이미지 push/pull
- S3: 결과 업로드
- SSM: Parameter Store 읽기
- CloudWatch Logs: 로그 작성

### S3 업로드 실패
```bash
# S3 버킷 존재 확인
aws s3 ls s3://devops-security-scan-results/ --region ap-northeast-2

# 버킷이 없으면 생성
aws s3 mb s3://devops-security-scan-results --region ap-northeast-2
```

## 11. 보안 스캔 결과 예시

### SonarCloud 메트릭 예시
```json
{
  "component": {
    "key": "Start-Cloud-Team_WebGoat",
    "name": "WebGoat",
    "measures": [
      {"metric": "bugs", "value": "5"},
      {"metric": "vulnerabilities", "value": "12"},
      {"metric": "code_smells", "value": "234"},
      {"metric": "security_hotspots", "value": "8"},
      {"metric": "coverage", "value": "45.2"}
    ]
  }
}
```

### Snyk SCA 결과 예시
```json
{
  "vulnerabilities": [
    {
      "id": "SNYK-JAVA-ORGSPRINGFRAMEWORK-12345",
      "title": "SQL Injection",
      "severity": "high",
      "packageName": "org.springframework:spring-core",
      "version": "5.3.10",
      "fixedIn": ["5.3.20"]
    }
  ],
  "summary": {
    "critical": 2,
    "high": 8,
    "medium": 15,
    "low": 23
  }
}
```

## 12. 파이프라인 흐름도

```
┌─────────────────┐
│  GitHub Push    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ CodeBuild Start │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────┐
│ Install Phase                       │
│ - Java 21                           │
│ - SonarScanner                      │
│ - Snyk CLI                          │
│ - ECR Login                         │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│ Pre_build Phase                     │
│ - Maven Compile                     │
│ - SonarCloud SAST Scan ✅          │
│ - Snyk SCA Scan ✅                 │
│ - Docker Pull                       │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│ Build Phase                         │
│ - Docker Tag                        │
│ - Snyk Container Scan ✅           │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│ Post_build Phase                    │
│ - Docker Push to ECR                │
│ - Fetch SonarCloud Results          │
│ - Upload Results to S3              │
│ - Create ECS Deploy Files           │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────┐
│  Build Success  │
└─────────────────┘
```

## 13. 주요 파일 위치

### GitHub 저장소
- `buildspec.yml`: 루트 디렉토리
- `pom.xml`: Maven 설정 (의존성 정의)
- `src/main/java`: Java 소스 코드

### AWS 리소스
- CodeBuild 프로젝트: `bWAPP-CodeBuild`
- S3 버킷: `devops-security-scan-results`
- SSM Parameters:
  - `/devops/sonarcloud/token`
  - `/devops/snyk/token`
- ECR 저장소: `bwapp-image-repo`

## 14. 모니터링 및 알림

### CloudWatch Logs
- 로그 그룹: `/aws/codebuild/bWAPP-CodeBuild`
- 보존 기간: 기본 설정

### 빌드 알림 (선택사항)
SNS 토픽을 생성하여 빌드 성공/실패 알림 설정 가능:

```bash
# SNS 토픽 생성
aws sns create-topic --name codebuild-notifications --region ap-northeast-2

# CodeBuild에 알림 설정
aws codebuild update-project \
  --name bWAPP-CodeBuild \
  --region ap-northeast-2 \
  --notifications-config \
    notificationArn=arn:aws:sns:ap-northeast-2:329984431650:codebuild-notifications
```

## 15. 비용 최적화

### CodeBuild 비용
- 빌드 시간: 약 4분
- 컴퓨팅: BUILD_GENERAL1_MEDIUM
- 월 예상 비용: 빌드 횟수에 따라 다름

### 비용 절감 팁
1. 불필요한 빌드 최소화
2. 캐시 활용 (현재 미사용)
3. 빌드 타임아웃 설정 (현재 60분)

## 16. 참고 자료

### 공식 문서
- SonarCloud: https://docs.sonarcloud.io
- Snyk: https://docs.snyk.io
- AWS CodeBuild: https://docs.aws.amazon.com/codebuild

### 대시보드
- SonarCloud: https://sonarcloud.io/project/overview?id=Start-Cloud-Team_WebGoat
- Snyk: https://app.snyk.io
- AWS CodeBuild: https://console.aws.amazon.com/codesuite/codebuild/projects

## 17. 체크리스트

### 정상 작동 확인
- [ ] GitHub Webhook 연결 확인
- [ ] SSM에 토큰 저장 확인
- [ ] S3 버킷 존재 확인
- [ ] ECR 저장소 존재 확인
- [ ] CodeBuild IAM 권한 확인
- [ ] 최근 빌드 성공 확인
- [ ] S3에 스캔 결과 저장 확인
- [ ] SonarCloud 대시보드 업데이트 확인
- [ ] Snyk 대시보드 업데이트 확인

### 정기 점검 항목
- [ ] 토큰 만료 확인 (3개월마다)
- [ ] 스캔 도구 버전 업데이트
- [ ] 취약점 수정 진행 상황 확인
- [ ] S3 스토리지 용량 확인
