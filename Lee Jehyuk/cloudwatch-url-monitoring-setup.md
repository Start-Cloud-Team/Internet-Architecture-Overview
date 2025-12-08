# CloudWatch URL 모니터링 및 Slack 알림 설정 가이드

## 개요
CloudWatch Synthetics Canary를 사용하여 URL을 주기적으로 체크하고, 실패 시 Slack으로 알림을 보내는 설정

## 1. Slack Webhook URL 생성

1. https://api.slack.com/apps 접속
2. "Create New App" → "From scratch"
3. 앱 이름 입력, 워크스페이스 선택
4. "Incoming Webhooks" 활성화
5. "Add New Webhook to Workspace" → 알림 받을 채널 선택
6. Webhook URL 복사 (예: `https://hooks.slack.com/services/T.../B.../...`)

## 2. Webhook URL을 AWS SSM Parameter Store에 저장

```bash
aws ssm put-parameter \
  --name /slack/webhook \
  --value "YOUR_WEBHOOK_URL" \
  --type SecureString \
  --region ap-northeast-2
```

## 3. Canary 스크립트 작성

```bash
mkdir -p /tmp/nodejs/node_modules
cat > /tmp/nodejs/node_modules/index.js << 'EOF'
const synthetics = require('Synthetics');

exports.handler = async () => {
    await synthetics.executeHttpStep('Check URL', 'YOUR_URL_HERE');
};
EOF

cd /tmp && zip -r canary.zip nodejs/
```

## 4. S3 버킷 확인 및 업로드

```bash
# S3 버킷 이름 확인 (없으면 생성)
BUCKET_NAME="cw-syn-results-YOUR_ACCOUNT_ID-ap-northeast-2"

# Canary 코드 업로드
aws s3 cp /tmp/canary.zip s3://${BUCKET_NAME}/canary.zip --region ap-northeast-2
```

## 5. IAM Role 확인

CloudWatchSyntheticsRole이 있는지 확인하고 없으면 생성:

```bash
aws iam get-role --role-name CloudWatchSyntheticsRole --region ap-northeast-2
```

## 6. Canary 생성

```bash
aws synthetics create-canary \
  --name bwapp-health-check \
  --artifact-s3-location s3://${BUCKET_NAME} \
  --execution-role-arn arn:aws:iam::YOUR_ACCOUNT_ID:role/CloudWatchSyntheticsRole \
  --schedule '{"Expression":"rate(1 minute)"}' \
  --runtime-version syn-nodejs-puppeteer-6.2 \
  --code '{"S3Bucket":"'${BUCKET_NAME}'","S3Key":"canary.zip","Handler":"index.handler"}' \
  --region ap-northeast-2
```

## 7. Canary 시작

```bash
# 생성 완료 대기 (약 10초)
sleep 10

aws synthetics start-canary \
  --name bwapp-health-check \
  --region ap-northeast-2
```

## 8. Lambda 함수 생성 (Slack 알림용)

```python
# /tmp/monitor.py
import boto3
import json
import urllib3

http = urllib3.PoolManager()
synthetics = boto3.client('synthetics')
ssm = boto3.client('ssm')

def lambda_handler(event, context):
    runs = synthetics.get_canary_runs(Name='bwapp-health-check', MaxResults=1)
    
    if runs['CanaryRuns'] and runs['CanaryRuns'][0]['Status']['TestResult'] == 'FAILED':
        webhook_url = ssm.get_parameter(Name='/slack/webhook', WithDecryption=True)['Parameter']['Value']
        
        message = {
            "text": f"🚨 *bWAPP Health Check 실패*\n\n시간: {runs['CanaryRuns'][0]['Timeline']['Started']}\n상태: FAILED\n\nURL 접속 불가 상태가 지속되고 있습니다."
        }
        
        http.request('POST', webhook_url, body=json.dumps(message), headers={'Content-Type': 'application/json'})
    
    return {'statusCode': 200}
```

```bash
cd /tmp && zip monitor.zip monitor.py

aws lambda create-function \
  --function-name canary-failure-monitor \
  --runtime python3.12 \
  --role arn:aws:iam::YOUR_ACCOUNT_ID:role/CloudWatchSyntheticsRole \
  --handler monitor.lambda_handler \
  --zip-file fileb://monitor.zip \
  --timeout 30 \
  --region ap-northeast-2
```

## 9. Lambda에 필요한 권한 추가

```bash
# SNS Publish 권한
cat > /tmp/sns-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sns:Publish",
      "Resource": "arn:aws:sns:ap-northeast-2:YOUR_ACCOUNT_ID:cloudwatch-alarm-topic"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name CloudWatchSyntheticsRole \
  --policy-name SNSPublishPolicy \
  --policy-document file:///tmp/sns-policy.json

# SSM GetParameter 권한
cat > /tmp/ssm-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ssm:GetParameter",
      "Resource": "arn:aws:ssm:ap-northeast-2:YOUR_ACCOUNT_ID:parameter/slack/webhook"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name CloudWatchSyntheticsRole \
  --policy-name SSMGetParameter \
  --policy-document file:///tmp/ssm-policy.json
```

## 10. EventBridge 규칙 생성 (1분마다 Lambda 실행)

```bash
# EventBridge 규칙 생성
aws events put-rule \
  --name canary-check-every-minute \
  --schedule-expression "rate(1 minute)" \
  --state ENABLED \
  --region ap-northeast-2

# Lambda를 타겟으로 추가
aws events put-targets \
  --rule canary-check-every-minute \
  --targets "Id=1,Arn=arn:aws:lambda:ap-northeast-2:YOUR_ACCOUNT_ID:function:canary-failure-monitor" \
  --region ap-northeast-2

# Lambda 실행 권한 추가
aws lambda add-permission \
  --function-name canary-failure-monitor \
  --statement-id ScheduledInvoke \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:ap-northeast-2:YOUR_ACCOUNT_ID:rule/canary-check-every-minute \
  --region ap-northeast-2
```

## 11. CloudWatch 알람 생성 (선택사항)

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name bwapp-health-check-alarm \
  --alarm-description "Alert when bWAPP health check fails" \
  --actions-enabled \
  --alarm-actions arn:aws:sns:ap-northeast-2:YOUR_ACCOUNT_ID:cloudwatch-alarm-topic \
  --metric-name SuccessPercent \
  --namespace CloudWatchSynthetics \
  --statistic Average \
  --dimensions Name=CanaryName,Value=bwapp-health-check \
  --period 60 \
  --evaluation-periods 1 \
  --threshold 100 \
  --comparison-operator LessThanThreshold \
  --treat-missing-data breaching \
  --region ap-northeast-2
```

## 12. 테스트

```bash
# Lambda 직접 실행 테스트
aws lambda invoke \
  --function-name canary-failure-monitor \
  --region ap-northeast-2 \
  /tmp/test-response.json

cat /tmp/test-response.json
```

## URL 변경 방법

```bash
# 1. 새 스크립트 작성
cat > /tmp/nodejs/node_modules/index.js << 'EOF'
const synthetics = require('Synthetics');

exports.handler = async () => {
    await synthetics.executeHttpStep('Check URL', 'NEW_URL_HERE');
};
EOF

# 2. 재압축 및 업로드
cd /tmp && rm -f canary.zip && zip -r canary.zip nodejs/
aws s3 cp /tmp/canary.zip s3://${BUCKET_NAME}/canary.zip --region ap-northeast-2

# 3. Canary 중지 및 업데이트
aws synthetics stop-canary --name bwapp-health-check --region ap-northeast-2
sleep 5

aws synthetics update-canary \
  --name bwapp-health-check \
  --code '{"S3Bucket":"'${BUCKET_NAME}'","S3Key":"canary.zip","Handler":"index.handler"}' \
  --region ap-northeast-2

sleep 10

# 4. Canary 재시작
aws synthetics start-canary --name bwapp-health-check --region ap-northeast-2
```

## 리소스 삭제 방법

```bash
# 1. EventBridge 규칙 삭제
aws events remove-targets --rule canary-check-every-minute --ids 1 --region ap-northeast-2
aws events delete-rule --name canary-check-every-minute --region ap-northeast-2

# 2. Lambda 삭제
aws lambda delete-function --function-name canary-failure-monitor --region ap-northeast-2

# 3. Canary 삭제
aws synthetics stop-canary --name bwapp-health-check --region ap-northeast-2
sleep 5
aws synthetics delete-canary --name bwapp-health-check --region ap-northeast-2

# 4. CloudWatch 알람 삭제
aws cloudwatch delete-alarms --alarm-names bwapp-health-check-alarm --region ap-northeast-2

# 5. SSM Parameter 삭제
aws ssm delete-parameter --name /slack/webhook --region ap-northeast-2
```

## 동작 방식

1. **Canary**: 1분마다 지정된 URL에 HTTP 요청
2. **EventBridge**: 1분마다 Lambda 함수 실행
3. **Lambda**: 최근 Canary 실행 결과 확인
4. **실패 시**: Slack Webhook으로 알림 전송
5. **성공 시**: 아무 동작 안 함

## 주의사항

- `YOUR_ACCOUNT_ID`를 실제 AWS 계정 ID로 변경
- `YOUR_URL_HERE`를 모니터링할 실제 URL로 변경
- Webhook URL은 절대 공개하지 말 것
- Canary 이름을 변경하면 Lambda 코드도 수정 필요
