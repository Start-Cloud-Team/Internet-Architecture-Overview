# Snyk 취약점 스캔 실습 가이드

## 목표
- High 취약점이 발견되어도 빌드가 중단되지 않도록 설정
- Snyk GUI 대시보드에서 취약점 확인

## 사전 준비

### 1. Snyk 계정 생성 및 API 토큰 발급
1. https://snyk.io 접속
2. 무료 계정 생성 (GitHub 계정으로 로그인 가능)
3. Account Settings > API Token 메뉴에서 토큰 복사

### 2. Snyk 토큰을 AWS Parameter Store에 저장
```bash
./setup-snyk-token.sh
```
또는 직접 명령어 실행:
```bash
aws ssm put-parameter \
    --name "/snyk/api-token" \
    --value "YOUR_SNYK_TOKEN" \
    --type "SecureString" \
    --region ap-northeast-2 \
    --overwrite
```

### 3. CodeBuild IAM Role에 권한 추가

#### 방법 1: AWS CLI 사용
```bash
# CodeBuild 프로젝트의 서비스 역할 이름 확인
aws codebuild batch-get-projects \
    --names bwapp-pipeline \
    --region ap-northeast-2 \
    --query 'projects[0].serviceRole' \
    --output text

# 역할 이름을 확인한 후 정책 연결
aws iam put-role-policy \
    --role-name <CodeBuild-Role-Name> \
    --policy-name SnykParameterStoreAccess \
    --policy-document file://codebuild-snyk-policy.json
```

#### 방법 2: AWS Console 사용
1. IAM Console > Roles
2. CodeBuild 역할 검색 (예: codebuild-bwapp-pipeline-service-role)
3. "Add permissions" > "Create inline policy"
4. JSON 탭에서 `codebuild-snyk-policy.json` 내용 붙여넣기
5. 정책 이름: `SnykParameterStoreAccess`

### 4. buildspec 파일 업데이트

#### Git 저장소가 있는 경우:
```bash
# 기존 buildspec.yml을 새 파일로 교체
cp buildspec_with_snyk.yml <your-repo>/buildspec.yml
cd <your-repo>
git add buildspec.yml
git commit -m "Add Snyk scanning with non-blocking mode"
git push
```

#### CodeBuild에서 직접 사용하는 경우:
1. CodeBuild Console > 프로젝트 선택
2. "Edit" > "Buildspec"
3. `buildspec_with_snyk.yml` 내용을 복사하여 붙여넣기

## 주요 변경 사항 설명

### 1. Snyk 스캔이 빌드를 중단하지 않는 이유
```yaml
- snyk container test webgoat/webgoat:latest --json-file-output=snyk-results.json || true
```
- `|| true`: 명령어가 실패해도 빌드를 계속 진행
- High/Critical 취약점이 있어도 exit code 0 반환

### 2. Snyk 대시보드에 결과 업로드
```yaml
- snyk container monitor webgoat/webgoat:latest --project-name=bwapp-pipeline || true
```
- `monitor` 명령어로 Snyk 대시보드에 스캔 결과 전송
- GUI에서 취약점 확인 가능

### 3. 결과 파일 저장
```yaml
artifacts:
  files:
    - snyk-results.json
```
- 스캔 결과를 JSON 파일로 저장
- CodeBuild 아티팩트로 다운로드 가능

## 실습 단계

### Step 1: 파이프라인 실행
```bash
# CodeBuild 프로젝트 시작
aws codebuild start-build \
    --project-name bwapp-pipeline \
    --region ap-northeast-2
```

### Step 2: 빌드 로그 확인
1. CodeBuild Console에서 빌드 진행 상황 확인
2. "=== SNYK SCAN (Non-blocking) ===" 로그 확인
3. High 취약점이 있어도 빌드가 계속 진행되는지 확인

### Step 3: Snyk GUI에서 취약점 확인
1. https://app.snyk.io 로그인
2. Projects 메뉴에서 "bwapp-pipeline" 프로젝트 찾기
3. 발견된 취약점 목록 확인:
   - Critical: 즉시 수정 필요
   - High: 우선순위 높음
   - Medium: 중간 우선순위
   - Low: 낮은 우선순위

### Step 4: 취약점 상세 정보 확인
- 각 취약점 클릭 시 확인 가능한 정보:
  - CVE 번호
  - 취약점 설명
  - 영향받는 패키지 버전
  - 수정 방법 (Fix advice)
  - 우선순위 점수

### Step 5: JSON 결과 파일 다운로드 (선택사항)
```bash
# 빌드 ID 확인
BUILD_ID=$(aws codebuild list-builds-for-project \
    --project-name bwapp-pipeline \
    --region ap-northeast-2 \
    --query 'ids[0]' \
    --output text)

# 아티팩트 위치 확인
aws codebuild batch-get-builds \
    --ids $BUILD_ID \
    --region ap-northeast-2 \
    --query 'builds[0].artifacts.location'

# S3에서 다운로드
aws s3 cp s3://<bucket-name>/<path>/snyk-results.json ./
```

## 고급 설정 (선택사항)

### 1. 특정 심각도 이상만 빌드 중단
Critical만 빌드 중단하려면:
```yaml
- snyk container test webgoat/webgoat:latest --severity-threshold=critical
```

### 2. HTML 리포트 생성
```yaml
- snyk container test webgoat/webgoat:latest --json | snyk-to-html -o snyk-report.html || true
```

### 3. Slack 알림 추가
```yaml
- |
  if [ -f snyk-results.json ]; then
    VULN_COUNT=$(cat snyk-results.json | jq '.uniqueCount')
    curl -X POST -H 'Content-type: application/json' \
      --data "{\"text\":\"Snyk found $VULN_COUNT vulnerabilities in bwapp-pipeline\"}" \
      $SLACK_WEBHOOK_URL
  fi
```

## 트러블슈팅

### 문제 1: Snyk 인증 실패
```
Error: Authentication failed
```
해결: Parameter Store에 토큰이 올바르게 저장되었는지 확인
```bash
aws ssm get-parameter --name "/snyk/api-token" --with-decryption --region ap-northeast-2
```

### 문제 2: IAM 권한 오류
```
Error: AccessDeniedException
```
해결: CodeBuild 역할에 SSM 권한이 있는지 확인

### 문제 3: Snyk 대시보드에 프로젝트가 안 보임
- `snyk container monitor` 명령어가 실행되었는지 로그 확인
- Snyk 계정에서 Organization 설정 확인

## 참고 자료
- Snyk CLI 문서: https://docs.snyk.io/snyk-cli
- Snyk Container 스캔: https://docs.snyk.io/products/snyk-container
- AWS CodeBuild 환경 변수: https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-env-vars.html
