# AWS DevOps Slack 알림 설정 (민감정보 제거 버전)

> ⚠️ 본 문서는 업로드한 원본 파일에서 **모든 민감 정보(AWS 계정, ARN, Slack ID, Webhook URL, 리전, 버킷명, 프로젝트명 등)**을 제거하고 **빈칸(_____)**으로 치환한 버전입니다.

---

## 📋 프로젝트 개요
AWS CodePipeline, CodeBuild에서 발생하는 빌드 및 보안 스캔 결과를 Slack으로 자동 알림 전송

---

## 🏗️ 최종 아키텍처

### 1. 파이프라인 & 빌드 알림
```
CodePipeline (______________)
  ↓
EventBridge (CodeStar Notifications)
  ↓
AWS Chatbot
  ↓
Slack (______________)
```

### 2. SAST/SCA 보안 스캔 결과 알림
```
CodeBuild (______________)
  ↓
S3 (______________)
  ↓ S3 Event Trigger
Lambda (______________)
  ↓ Slack Webhook
Slack (______________)
```

---

## 📊 알림 채널 구성

### 빌드 알림 채널
- 채널 ID: ______________
- 파이프라인 시작/성공/실패  
- CodeBuild 빌드 성공/실패  
- DAST 실행 결과

### 보안 스캔 채널
- 채널 ID: ______________
- SAST 결과 (SonarCloud)  
- SCA 결과 (Snyk – 의존성/컨테이너 취약점)

---

## 🔧 주요 설정 내역

### 1. AWS Chatbot 설정

#### Slack 워크스페이스 연결
- 워크스페이스: ______________
- 상태: ENABLED

#### Chatbot 채널 설정
```json
{
  "ConfigurationName": "______________",
  "SlackChannelId": "______________",
  "SlackChannelName": "______________",
  "IamRoleArn": "arn:aws:iam::__ACCOUNT_ID__:role/______________",
  "LoggingLevel": "ERROR",
  "State": "ENABLED"
}
```

---

## 2. CodeStar Notification Rules

### 파이프라인 알림
```bash
aws codestar-notifications create-notification-rule   --name ______________   --event-type-ids     codepipeline-pipeline-pipeline-execution-started     codepipeline-pipeline-pipeline-execution-succeeded     codepipeline-pipeline-pipeline-execution-failed   --resource arn:aws:codepipeline:__REGION__:__ACCOUNT_ID__:______________   --targets '[{"TargetType":"AWSChatbotSlack","TargetAddress":"arn:aws:chatbot::__ACCOUNT_ID__:chat-configuration/slack-channel/______________"}]'   --status ENABLED   --detail-type FULL
```

### CodeBuild 알림
```bash
aws codestar-notifications create-notification-rule   --name ______________   --event-type-ids     codebuild-project-build-state-succeeded     codebuild-project-build-state-failed   --resource arn:aws:codebuild:__REGION__:__ACCOUNT_ID__:project/______________   --targets '[{"TargetType":"AWSChatbotSlack","TargetAddress":"arn:aws:chatbot::__ACCOUNT_ID__:chat-configuration/slack-channel/______________"}]'   --status ENABLED   --detail-type FULL
```

---

## 3. Lambda 함수 설정

### 환경 변수
```
SLACK_WEBHOOK_URL=____________________________________
```

### S3 트리거 설정
```json
{
  "LambdaFunctionConfigurations": [
    {
      "Id": "sonarqube-scan-trigger",
      "LambdaFunctionArn": "arn:aws:lambda:__REGION__:__ACCOUNT_ID__:function:______________",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            {"Name": "Prefix", "Value": "sonarqube/"},
            {"Name": "Suffix", "Value": ".json"}
          ]
        }
      }
    },
    {
      "Id": "snyk-scan-trigger",
      "LambdaFunctionArn": "arn:aws:lambda:__REGION__:__ACCOUNT_ID__:function:______________",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            {"Name": "Prefix", "Value": "snyk/"},
            {"Name": "Suffix", "Value": ".json"}
          ]
        }
      }
    }
  ]
}
```

---

## 4. buildspec.yml 주요 수정

```yaml
- snyk test --all-projects --json-file-output=snyk-sca-results.json || true
- test -f snyk-sca-results.json || echo '{"error":"Snyk SCA scan failed"}' > snyk-sca-results.json

- snyk container test __IMAGE_URI__ --json-file-output=snyk-container-results.json || true
- test -f snyk-container-results.json || echo '{"error":"Snyk Container scan failed"}' > snyk-container-results.json
```

---

## 📁 S3 버킷 구조
```
______________/
  ├── snyk/
  └── sonarqube/
```

---

## 🔑 주요 리소스 (익명화)

IAM Role  
```
arn:aws:iam::__ACCOUNT_ID__:role/______________
```

SNS Topics  
```
arn:aws:sns:__REGION__:__ACCOUNT_ID__:______________
```

Lambda  
```
arn:aws:lambda:__REGION__:__ACCOUNT_ID__:function:______________
```

Chatbot  
```
arn:aws:chatbot::__ACCOUNT_ID__:chat-configuration/slack-channel/______________
```

---

## 보안 스캔 예시 (민감 정보 없음)

### SAST
```
Bugs: 29
Vulnerabilities: 0
Code Smells: 261
Security Hotspots: 46
```

### SCA
```
Found 42 issues
```

---

## 최종 정리
- 모든 민감 정보는 **빈칸(_____)**으로 치환 완료  
