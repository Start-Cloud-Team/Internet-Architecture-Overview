# CloudWatch ECS CPU/메모리 모니터링 및 Slack 알림 설정 가이드

## 개요
ECS 서비스의 CPU와 메모리 사용률을 5분마다 체크하고, 80% 이상일 때 Slack으로 알림을 보내는 설정

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
  --name /slack/cpu-ram-webhook \
  --value "YOUR_WEBHOOK_URL" \
  --type SecureString \
  --region ap-northeast-2
```

## 3. Lambda 함수 코드 작성

```python
# /tmp/ecs_monitor.py
import boto3
import json
import urllib3
from datetime import datetime, timedelta

http = urllib3.PoolManager()
cloudwatch = boto3.client('cloudwatch')
ssm = boto3.client('ssm')

def lambda_handler(event, context):
    cluster = 'YOUR_CLUSTER_NAME'
    service = 'YOUR_SERVICE_NAME'
    
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(minutes=5)
    
    # CPU 사용률 확인
    cpu_response = cloudwatch.get_metric_statistics(
        Namespace='AWS/ECS',
        MetricName='CPUUtilization',
        Dimensions=[
            {'Name': 'ClusterName', 'Value': cluster},
            {'Name': 'ServiceName', 'Value': service}
        ],
        StartTime=start_time,
        EndTime=end_time,
        Period=300,
        Statistics=['Average']
    )
    
    # 메모리 사용률 확인
    mem_response = cloudwatch.get_metric_statistics(
        Namespace='AWS/ECS',
        MetricName='MemoryUtilization',
        Dimensions=[
            {'Name': 'ClusterName', 'Value': cluster},
            {'Name': 'ServiceName', 'Value': service}
        ],
        StartTime=start_time,
        EndTime=end_time,
        Period=300,
        Statistics=['Average']
    )
    
    cpu_avg = cpu_response['Datapoints'][0]['Average'] if cpu_response['Datapoints'] else 0
    mem_avg = mem_response['Datapoints'][0]['Average'] if mem_response['Datapoints'] else 0
    
    # 테스트 모드
    if event.get('test_mode'):
        cpu_avg = 85.5
        mem_avg = 92.3
    
    alerts = []
    if cpu_avg >= 80:
        alerts.append(f"🔴 CPU: {cpu_avg:.1f}% (임계값: 80%)")
    if mem_avg >= 80:
        alerts.append(f"🔴 메모리: {mem_avg:.1f}% (임계값: 80%)")
    
    if alerts:
        webhook_url = ssm.get_parameter(Name='/slack/cpu-ram-webhook', WithDecryption=True)['Parameter']['Value']
        
        message = {
            "text": f"⚠️ *ECS 리소스 경고 - {cluster}*\n\n" + "\n".join(alerts) + f"\n\n서비스: {service}\n시간: {end_time.strftime('%Y-%m-%d %H:%M:%S')} UTC"
        }
        
        http.request('POST', webhook_url, body=json.dumps(message), headers={'Content-Type': 'application/json'})
    
    return {'statusCode': 200, 'cpu': cpu_avg, 'memory': mem_avg}
```

**주의:** `YOUR_CLUSTER_NAME`과 `YOUR_SERVICE_NAME`을 실제 값으로 변경하세요.

## 4. ECS 클러스터 및 서비스 이름 확인

```bash
# 클러스터 목록 확인
aws ecs list-clusters --region ap-northeast-2

# 특정 클러스터의 서비스 목록 확인
aws ecs list-services --cluster YOUR_CLUSTER_NAME --region ap-northeast-2
```

## 5. Lambda 함수 생성

```bash
cd /tmp && zip ecs_monitor.zip ecs_monitor.py

aws lambda create-function \
  --function-name ecs-cpu-memory-monitor \
  --runtime python3.12 \
  --role arn:aws:iam::YOUR_ACCOUNT_ID:role/CloudWatchSyntheticsRole \
  --handler ecs_monitor.lambda_handler \
  --zip-file fileb://ecs_monitor.zip \
  --timeout 30 \
  --region ap-northeast-2
```

**참고:** IAM Role이 없다면 먼저 생성해야 합니다.

## 6. Lambda에 필요한 권한 추가

```bash
# SSM GetParameter 권한
cat > /tmp/ssm-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ssm:GetParameter",
      "Resource": "arn:aws:ssm:ap-northeast-2:YOUR_ACCOUNT_ID:parameter/slack/cpu-ram-webhook"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name CloudWatchSyntheticsRole \
  --policy-name SSMGetParameterCPURAM \
  --policy-document file:///tmp/ssm-policy.json

# CloudWatch 읽기 권한 (이미 있을 수 있음)
aws iam attach-role-policy \
  --role-name CloudWatchSyntheticsRole \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess
```

## 7. EventBridge 규칙 생성 (5분마다 실행)

```bash
# EventBridge 규칙 생성
aws events put-rule \
  --name ecs-monitor-every-5min \
  --schedule-expression "rate(5 minutes)" \
  --state ENABLED \
  --region ap-northeast-2

# Lambda를 타겟으로 추가
aws events put-targets \
  --rule ecs-monitor-every-5min \
  --targets "Id=1,Arn=arn:aws:lambda:ap-northeast-2:YOUR_ACCOUNT_ID:function:ecs-cpu-memory-monitor" \
  --region ap-northeast-2

# Lambda 실행 권한 추가
aws lambda add-permission \
  --function-name ecs-cpu-memory-monitor \
  --statement-id ECSMonitorSchedule \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:ap-northeast-2:YOUR_ACCOUNT_ID:rule/ecs-monitor-every-5min \
  --region ap-northeast-2
```

## 8. 테스트

### 일반 테스트 (실제 메트릭 확인)
```bash
aws lambda invoke \
  --function-name ecs-cpu-memory-monitor \
  --region ap-northeast-2 \
  /tmp/test-response.json

cat /tmp/test-response.json
```

### 알림 테스트 (강제로 80% 이상 값 생성)
```bash
aws lambda invoke \
  --function-name ecs-cpu-memory-monitor \
  --cli-binary-format raw-in-base64-out \
  --payload '{"test_mode": true}' \
  --region ap-northeast-2 \
  /tmp/test-response.json

cat /tmp/test-response.json
```

## 임계값 변경 방법

Lambda 코드에서 임계값을 수정:

```python
# 현재: 80%
if cpu_avg >= 80:
    alerts.append(f"🔴 CPU: {cpu_avg:.1f}% (임계값: 80%)")
if mem_avg >= 80:
    alerts.append(f"🔴 메모리: {mem_avg:.1f}% (임계값: 80%)")

# 예: 70%로 변경
if cpu_avg >= 70:
    alerts.append(f"🔴 CPU: {cpu_avg:.1f}% (임계값: 70%)")
if mem_avg >= 70:
    alerts.append(f"🔴 메모리: {mem_avg:.1f}% (임계값: 70%)")
```

변경 후 Lambda 업데이트:
```bash
cd /tmp && zip ecs_monitor.zip ecs_monitor.py
aws lambda update-function-code \
  --function-name ecs-cpu-memory-monitor \
  --zip-file fileb://ecs_monitor.zip \
  --region ap-northeast-2
```

## 체크 주기 변경 방법

EventBridge 규칙 수정:

```bash
# 현재: 5분마다
# 1분마다로 변경
aws events put-rule \
  --name ecs-monitor-every-5min \
  --schedule-expression "rate(1 minute)" \
  --state ENABLED \
  --region ap-northeast-2

# 10분마다로 변경
aws events put-rule \
  --name ecs-monitor-every-5min \
  --schedule-expression "rate(10 minutes)" \
  --state ENABLED \
  --region ap-northeast-2
```

## 모니터링 대상 변경 방법

Lambda 코드에서 클러스터/서비스 이름 변경:

```python
# 변경 전
cluster = 'Bwapp-cluster'
service = 'bWAPP-task-service'

# 변경 후
cluster = 'NEW_CLUSTER_NAME'
service = 'NEW_SERVICE_NAME'
```

변경 후 Lambda 업데이트:
```bash
cd /tmp && zip ecs_monitor.zip ecs_monitor.py
aws lambda update-function-code \
  --function-name ecs-cpu-memory-monitor \
  --zip-file fileb://ecs_monitor.zip \
  --region ap-northeast-2
```

## 리소스 삭제 방법

```bash
# 1. EventBridge 규칙 삭제
aws events remove-targets --rule ecs-monitor-every-5min --ids 1 --region ap-northeast-2
aws events delete-rule --name ecs-monitor-every-5min --region ap-northeast-2

# 2. Lambda 삭제
aws lambda delete-function --function-name ecs-cpu-memory-monitor --region ap-northeast-2

# 3. SSM Parameter 삭제
aws ssm delete-parameter --name /slack/cpu-ram-webhook --region ap-northeast-2

# 4. IAM 정책 삭제 (선택사항)
aws iam delete-role-policy --role-name CloudWatchSyntheticsRole --policy-name SSMGetParameterCPURAM
```

## 동작 방식

1. **EventBridge**: 5분마다 Lambda 함수 실행
2. **Lambda**: 최근 5분간 ECS 서비스의 CPU/메모리 평균 사용률 조회
3. **임계값 체크**: CPU 또는 메모리가 80% 이상인지 확인
4. **알림 발송**: 임계값 초과 시 Slack Webhook으로 알림 전송
5. **정상 시**: 아무 동작 안 함

## 알림 예시

```
⚠️ ECS 리소스 경고 - Bwapp-cluster

🔴 CPU: 85.5% (임계값: 80%)
🔴 메모리: 92.3% (임계값: 80%)

서비스: bWAPP-task-service
시간: 2025-12-05 14:52:00 UTC
```

## 주의사항

- `YOUR_ACCOUNT_ID`를 실제 AWS 계정 ID로 변경
- `YOUR_CLUSTER_NAME`, `YOUR_SERVICE_NAME`을 실제 값으로 변경
- Webhook URL은 절대 공개하지 말 것
- ECS 서비스에 CloudWatch Container Insights가 활성화되어 있어야 메트릭 수집 가능
- 테스트 모드는 실제 운영 환경에서는 제거할 것

## CloudWatch Container Insights 활성화 (필요 시)

```bash
aws ecs update-cluster-settings \
  --cluster YOUR_CLUSTER_NAME \
  --settings name=containerInsights,value=enabled \
  --region ap-northeast-2
```

## 트러블슈팅

### 메트릭이 수집되지 않는 경우
- Container Insights가 활성화되어 있는지 확인
- ECS 서비스가 실행 중인지 확인
- Lambda 실행 로그 확인: CloudWatch Logs → `/aws/lambda/ecs-cpu-memory-monitor`

### 알림이 오지 않는 경우
- Lambda 테스트 모드로 실행해서 Slack 연동 확인
- Webhook URL이 올바른지 확인
- SSM Parameter가 제대로 저장되었는지 확인

### 권한 오류
- IAM Role에 필요한 권한이 모두 있는지 확인
- CloudWatch 읽기 권한, SSM GetParameter 권한 필요
