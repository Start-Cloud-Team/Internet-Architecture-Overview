# AWS 보안 도구 설정 및 연결 가이드

## 목차
1. [SAST (Static Application Security Testing) 설정](#1-sast-설정)
2. [SCA (Software Composition Analysis) 설정](#2-sca-설정)
3. [Slack 연동 설정](#3-slack-연동-설정)
4. [S3 권한 설정](#4-s3-권한-설정)
5. [전체 아키텍처 흐름](#5-전체-아키텍처-흐름)

---

## 1. SAST 설정

### 1.1 SonarCloud 설정

#### 사용 도구
- **SonarCloud**: 코드 품질 및 보안 취약점 분석

#### 설정 방법

**1) SonarCloud 토큰 생성**
- SonarCloud 웹사이트에서 API 토큰 생성
- Organization: `_______________`
- Project Key: `_______________`

**2) AWS Systems Manager Parameter Store에 토큰 저장**
```bash
aws ssm put-parameter \
  --name "/devops/sonarcloud/token" \
  --value "YOUR_SONARCLOUD_TOKEN" \
  --type "SecureString" \
  --region ap-northeast-2
```

**3) CodeBuild에서 SAST 스캔 실행**

buildspec.yml 설정:
```yaml
env:
  parameter-store:
    SONAR_TOKEN: /devops/sonarcloud/token

phases:
  install:
    commands:
      - wget -q https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-6.2.1.4610-linux-x64.zip
      - unzip -q sonar-scanner-cli-6.2.1.4610-linux-x64.zip
  
  pre_build:
    commands:
      - ./sonar-scanner-6.2.1.4610-linux-x64/bin/sonar-scanner \
        -Dsonar.projectKey=YOUR_PROJECT_KEY \
        -Dsonar.organization=YOUR_ORGANIZATION \
        -Dsonar.sources=src/main/java \
        -Dsonar.java.binaries=target/classes \
        -Dsonar.branch.name=main \
        -Dsonar.host.url=https://sonarcloud.io \
        -Dsonar.token=$SONAR_TOKEN
```

**4) 스캔 결과 수집**
```yaml
post_build:
  commands:
    - curl -u $SONAR_TOKEN: "https://sonarcloud.io/api/issues/search?componentKeys=YOUR_PROJECT_KEY&resolved=false" -o sonarcloud-issues.json
    - curl -u $SONAR_TOKEN: "https://sonarcloud.io/api/measures/component?component=YOUR_PROJECT_KEY&metricKeys=bugs,vulnerabilities,code_smells,coverage,security_hotspots" -o sonarcloud-metrics.json
```

---

## 2. SCA 설정

### 2.1 Snyk 설정

#### 사용 도구
- **Snyk**: 오픈소스 의존성 취약점 분석 및 컨테이너 스캔

#### 설정 방법

**1) Snyk 토큰 생성**
- Snyk 웹사이트에서 API 토큰 생성

**2) AWS Systems Manager Parameter Store에 토큰 저장**
```bash
aws ssm put-parameter \
  --name "/devops/snyk/token" \
  --value "YOUR_SNYK_TOKEN" \
  --type "SecureString" \
  --region ap-northeast-2
```

**3) CodeBuild에서 SCA 스캔 실행**

buildspec.yml 설정:
```yaml
env:
  parameter-store:
    SNYK_TOKEN: /devops/snyk/token

phases:
  install:
    commands:
      - curl -Lo snyk https://static.snyk.io/cli/latest/snyk-linux
      - chmod +x snyk
      - mv snyk /usr/local/bin/snyk
  
  pre_build:
    commands:
      # Snyk 인증
      - snyk auth $SNYK_TOKEN
      
      # SCA 테스트 (의존성 스캔)
      - snyk test --all-projects --json-file-output=snyk-sca-results.json || true
      - snyk monitor --project-name=YOUR_PROJECT_NAME-SCA || true
  
  build:
    commands:
      # 컨테이너 이미지 스캔
      - snyk container test $ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG --json-file-output=snyk-container-results.json || true
      - snyk container monitor $ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG --project-name=YOUR_PROJECT_NAME-Container
```

---

## 3. Slack 연동 설정

### 3.1 Lambda를 통한 Slack 알림

#### 설정된 구성

**1) Lambda 함수: `security-scan-notifier`**
- Runtime: Python 3.11
- Role: `lambda-security-scan-role`
- 환경 변수:
  - `SLACK_WEBHOOK_URL`: Slack Incoming Webhook URL

**2) Slack Webhook URL 설정**
```bash
# Lambda 환경 변수로 설정
SLACK_WEBHOOK_URL=_______________________________________________
```

**3) SNS 토픽 연결**
- SNS 토픽: `security-scan-results`
- 구독: Lambda 함수가 SNS 토픽을 구독하여 알림 수신

**4) Lambda 함수 권한 설정**

IAM 역할 `lambda-security-scan-role`에 연결된 정책:
- `lambda-s3-read-policy`: S3에서 스캔 결과 읽기
- `lambda-sns-publish-policy`: SNS 토픽에 메시지 발행
- `AWSLambdaBasicExecutionRole`: CloudWatch Logs 작성

### 3.2 AWS Chatbot을 통한 Slack 연동

**1) Chatbot 역할: `chatbot-webgoat-role`**
- 정책: `AWS-Chatbot-NotificationsOnly-Policy`

**2) SNS 토픽 구독**
- `security-scan-results` 토픽이 Chatbot에 연결되어 Slack으로 알림 전송

**3) 설정 방법**
```bash
# AWS Chatbot 콘솔에서 설정
1. Slack 워크스페이스 연결
2. Slack 채널 선택
3. SNS 토픽 연결: security-scan-results
4. IAM 역할 지정: chatbot-webgoat-role
```

---

## 4. S3 권한 설정

### 4.1 보안 스캔 결과 저장용 S3 버킷

#### 버킷 정보
- **버킷 이름**: `devops-security-scan-results`
- **리전**: us-east-1

#### 권한 설정

**1) CodeBuild 역할에 S3 쓰기 권한 부여**

IAM 정책 `iac-codebuild-policy`에 포함된 S3 권한:
```json
{
  "Action": [
    "s3:PutObject",
    "s3:PutObjectAcl"
  ],
  "Effect": "Allow",
  "Resource": [
    "arn:aws:s3:::devops-security-scan-results/*"
  ]
}
```

**2) Lambda 역할에 S3 읽기 권한 부여**

IAM 정책 `lambda-s3-read-policy`:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::devops-security-scan-results",
        "arn:aws:s3:::devops-security-scan-results/*"
      ]
    }
  ]
}
```

**3) 스캔 결과 업로드**

buildspec.yml에서 S3 업로드:
```yaml
post_build:
  commands:
    - TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    - aws s3 cp snyk-sca-results.json s3://$S3_BUCKET/snyk/sca-$TIMESTAMP.json
    - aws s3 cp snyk-container-results.json s3://$S3_BUCKET/snyk/container-$TIMESTAMP.json
    - aws s3 cp sonarcloud-issues.json s3://$S3_BUCKET/sonarqube/issues-$TIMESTAMP.json
    - aws s3 cp sonarcloud-metrics.json s3://$S3_BUCKET/sonarqube/metrics-$TIMESTAMP.json
```

### 4.2 CodePipeline 아티팩트 저장용 S3 버킷

#### 버킷 정보
- **버킷 이름**: `iac-codepipeline-s3-bucket`
- **용도**: CodePipeline 아티팩트 저장

#### 권한 설정

CodeBuild 역할에 부여된 권한:
```json
{
  "Action": [
    "s3:GetObject",
    "s3:GetObjectVersion",
    "s3:GetBucketVersioning",
    "s3:PutObject",
    "s3:PutObjectAcl",
    "s3:ListBucket"
  ],
  "Effect": "Allow",
  "Resource": [
    "arn:aws:s3:::iac-codepipeline-s3-bucket",
    "arn:aws:s3:::iac-codepipeline-s3-bucket/*"
  ]
}
```

### 4.3 DAST 로그 저장용 S3 버킷

#### 버킷 정보
- **버킷 이름**: `webgoat-dast-logs-s3-iac`
- **용도**: StackHawk DAST 스캔 로그 저장

---

## 5. 전체 아키텍처 흐름

### 5.1 CI/CD 파이프라인 구성

```
GitHub → CodePipeline → CodeBuild (SAST/SCA) → ECR → ECS
                              ↓
                         S3 (결과 저장)
                              ↓
                         SNS 토픽
                              ↓
                    Lambda / AWS Chatbot
                              ↓
                            Slack
```

### 5.2 주요 CodeBuild 프로젝트

#### 1) iac-codebuild
- **역할**: SAST/SCA 스캔 및 Docker 이미지 빌드
- **소스**: GitHub
- **실행 내용**:
  - Maven 빌드
  - SonarCloud SAST 스캔
  - Snyk SCA 스캔
  - Docker 이미지 빌드 및 ECR 푸시
  - Snyk 컨테이너 스캔
  - 스캔 결과 S3 업로드

#### 2) iac-Webgoat-Dast_tool
- **역할**: DAST (Dynamic Application Security Testing) 스캔
- **도구**: StackHawk
- **실행 내용**:
  - SSM Parameter Store에서 API 키 및 타겟 URL 가져오기
  - StackHawk 스캔 실행
  - 로그 S3 업로드

### 5.3 IAM 역할 및 권한

#### CodeBuild 역할: `iac-codebuild-role`

연결된 정책: `iac-codebuild-policy`

주요 권한:
- **ECR**: 이미지 푸시/풀
- **S3**: 아티팩트 및 스캔 결과 읽기/쓰기
- **SSM Parameter Store**: 토큰 읽기
- **Secrets Manager**: 시크릿 읽기
- **CloudWatch Logs**: 로그 작성
- **ECS**: 태스크 정의 등록
- **CodeDeploy**: 배포 생성 및 조회

#### Lambda 역할: `lambda-security-scan-role`

연결된 정책:
- `lambda-s3-read-policy`: S3 읽기
- `lambda-sns-publish-policy`: SNS 발행
- `AWSLambdaBasicExecutionRole`: 기본 실행 권한

### 5.4 SSM Parameter Store 파라미터

| 파라미터 이름 | 타입 | 용도 |
|--------------|------|------|
| `/devops/sonarcloud/token` | SecureString | SonarCloud API 토큰 |
| `/devops/snyk/token` | SecureString | Snyk API 토큰 |
| `/hawk/api_key` | SecureString | StackHawk API 키 |
| `/hawk/target_url` | String | DAST 스캔 대상 URL |

### 5.5 SNS 토픽 및 구독

#### SNS 토픽: `security-scan-results`
- **ARN**: `arn:aws:sns:ap-northeast-2:<AWS_ACCOUNT_ID>:security-scan-results`
- **구독자**:
  - AWS Chatbot (Slack 연동)
  - Lambda 함수 `security-scan-notifier`

---

## 6. 설치 및 설정 단계별 가이드

### 6.1 사전 준비

1. **AWS CLI 설치 및 구성**
```bash
aws configure
```

2. **필요한 서비스 계정 생성**
- SonarCloud 계정
- Snyk 계정
- StackHawk 계정
- Slack 워크스페이스

### 6.2 단계별 설정

#### Step 1: S3 버킷 생성
```bash
# 보안 스캔 결과 저장용 버킷
aws s3 mb s3://devops-security-scan-results --region us-east-1

# CodePipeline 아티팩트 저장용 버킷
aws s3 mb s3://iac-codepipeline-s3-bucket --region ap-northeast-2

# DAST 로그 저장용 버킷
aws s3 mb s3://webgoat-dast-logs-s3-iac --region ap-northeast-2
```

#### Step 2: IAM 역할 및 정책 생성
```bash
# CodeBuild 역할 생성
aws iam create-role \
  --role-name iac-codebuild-role \
  --assume-role-policy-document file://codebuild-trust-policy.json

# 정책 연결
aws iam attach-role-policy \
  --role-name iac-codebuild-role \
  --policy-arn arn:aws:iam::<AWS_ACCOUNT_ID>:policy/iac-codebuild-policy
```

#### Step 3: SSM Parameter Store에 토큰 저장
```bash
# SonarCloud 토큰
aws ssm put-parameter \
  --name "/devops/sonarcloud/token" \
  --value "YOUR_TOKEN" \
  --type "SecureString" \
  --region ap-northeast-2

# Snyk 토큰
aws ssm put-parameter \
  --name "/devops/snyk/token" \
  --value "YOUR_TOKEN" \
  --type "SecureString" \
  --region ap-northeast-2

# StackHawk API 키
aws ssm put-parameter \
  --name "/hawk/api_key" \
  --value "YOUR_API_KEY" \
  --type "SecureString" \
  --region ap-northeast-2

# DAST 타겟 URL
aws ssm put-parameter \
  --name "/hawk/target_url" \
  --value "http://your-target-url.com" \
  --type "String" \
  --region ap-northeast-2
```

#### Step 4: SNS 토픽 생성 및 구독 설정
```bash
# SNS 토픽 생성
aws sns create-topic \
  --name security-scan-results \
  --region ap-northeast-2

# Lambda 함수 구독
aws sns subscribe \
  --topic-arn arn:aws:sns:ap-northeast-2:<AWS_ACCOUNT_ID>:security-scan-results \
  --protocol lambda \
  --notification-endpoint arn:aws:lambda:ap-northeast-2:<AWS_ACCOUNT_ID>:function:security-scan-notifier \
  --region ap-northeast-2
```

#### Step 5: Lambda 함수 생성 (Slack 알림용)
```bash
# Lambda 함수 생성
aws lambda create-function \
  --function-name security-scan-notifier \
  --runtime python3.11 \
  --role arn:aws:iam::<AWS_ACCOUNT_ID>:role/lambda-security-scan-role \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://function.zip \
  --environment Variables={SLACK_WEBHOOK_URL=YOUR_WEBHOOK_URL} \
  --region ap-northeast-2
```

#### Step 6: CodeBuild 프로젝트 생성
```bash
# SAST/SCA 스캔용 CodeBuild 프로젝트
aws codebuild create-project \
  --name iac-codebuild \
  --source type=GITHUB,location=https://github.com/YOUR_ORG/YOUR_REPO \
  --artifacts type=NO_ARTIFACTS \
  --environment type=LINUX_CONTAINER,image=aws/codebuild/standard:6.0,computeType=BUILD_GENERAL1_SMALL \
  --service-role arn:aws:iam::<AWS_ACCOUNT_ID>:role/iac-codebuild-role \
  --region ap-northeast-2
```

#### Step 7: AWS Chatbot 설정
1. AWS Chatbot 콘솔 접속
2. Slack 워크스페이스 연결
3. 채널 선택 및 SNS 토픽 연결
4. IAM 역할 지정: `chatbot-webgoat-role`

---

## 7. 트러블슈팅

### 7.1 SAST/SCA 스캔 실패 시

**증상**: SonarCloud 또는 Snyk 스캔이 실패함

**해결 방법**:
1. SSM Parameter Store에 토큰이 올바르게 저장되었는지 확인
```bash
aws ssm get-parameter --name "/devops/sonarcloud/token" --with-decryption --region ap-northeast-2
```

2. CodeBuild 역할에 SSM 읽기 권한이 있는지 확인
3. 토큰이 만료되지 않았는지 확인

### 7.2 S3 업로드 실패 시

**증상**: 스캔 결과가 S3에 업로드되지 않음

**해결 방법**:
1. CodeBuild 역할에 S3 쓰기 권한이 있는지 확인
2. S3 버킷 정책 확인
3. CloudWatch Logs에서 에러 메시지 확인

### 7.3 Slack 알림이 오지 않을 때

**증상**: 스캔 완료 후 Slack 알림이 오지 않음

**해결 방법**:
1. Slack Webhook URL이 올바른지 확인
2. Lambda 함수 환경 변수 확인
3. SNS 토픽 구독 상태 확인
4. Lambda 함수 CloudWatch Logs 확인

---

## 8. 참고 자료

### 8.1 현재 설정된 리소스 목록

#### S3 버킷
- `devops-security-scan-results`
- `iac-codepipeline-s3-bucket`
- `webgoat-dast-logs-s3-iac`

#### CodeBuild 프로젝트
- `iac-codebuild` (SAST/SCA)
- `iac-Webgoat-Dast_tool` (DAST)
- `Webgoat-Dast_tool` (DAST - GitHub 트리거)
- `bWAPP-CodeBuild`

#### CodePipeline
- `iac-codepipeline`
- `webgoat-pipeline`
- `Bwapp-pipeline`

#### Lambda 함수
- `security-scan-notifier` (Slack 알림)
- `canary-failure-monitor`
- `ecs-cpu-memory-monitor`

#### SNS 토픽
- `security-scan-results`
- `webgoat-build-notifications`
- `webgoat-pipeline-notifications`
- `cloudwatch-alarm-topic`

#### IAM 역할
- `iac-codebuild-role`
- `hawk-dast-codebuild-role`
- `lambda-security-scan-role`
- `chatbot-webgoat-role`
- `iac-codepipeline-role`
- `iac-codedeploy-role`

---

## 9. 보안 모범 사례

1. **토큰 관리**
   - 모든 API 토큰은 SSM Parameter Store의 SecureString으로 저장
   - 정기적으로 토큰 교체
   - 최소 권한 원칙 적용

2. **S3 버킷 보안**
   - 버킷 암호화 활성화
   - 버킷 정책으로 접근 제한
   - 버전 관리 활성화

3. **IAM 권한**
   - 최소 권한 원칙 적용
   - 역할 기반 접근 제어 사용
   - 정기적인 권한 검토

4. **로깅 및 모니터링**
   - CloudWatch Logs 활성화
   - CloudWatch Alarms 설정
   - AWS CloudTrail 활성화

---

**문서 작성일**: 2025-12-08  
**주요 리전**: ap-northeast-2 (서울)
