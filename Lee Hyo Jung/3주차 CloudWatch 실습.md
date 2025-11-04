# **📘 Amazon CloudWatch 서비스 기능 및 실습 정리**

## **🧩 1. CloudWatch 개요**

**Amazon CloudWatch**는 AWS 리소스(EC2, RDS 등)와 애플리케이션에서 발생하는 로그, 지표(Metrics), 이벤트를 실시간으로 모니터링하고,

이상 상태가 감지되면 경보(Alarm)를 통해 알림을 보내는 서비스입니다.

---

## **⚙️ 2. 실습 목표**

- EC2 인스턴스의 **CPU 사용률**이 60%를 초과하면 **이메일로 알림을 받는 경보(Alarm)** 생성
- CloudWatch Agent를 통해 **EC2 내부 지표(메모리, 디스크 등)** 도 수집
- SNS(Simple Notification Service)를 이용해 알림 전송

---

## **🧭 3. 전체 실습 순서 요약**

| **단계** | **주요 내용** | **도구** |
| --- | --- | --- |
| ① | SNS 주제 생성 | Amazon SNS |
| ② | EC2 인스턴스 생성 및 역할 부여 | Amazon EC2 |
| ③ | CloudWatch Agent 설치 및 실행 | EC2 터미널 |
| ④ | CloudWatch 지표 및 경보 생성 | CloudWatch 콘솔 |
| ⑤ | CPU 부하 테스트 | EC2 터미널 |
| ⑥ | 이메일 알림 확인 | Gmail |

---

## **📍 4. SNS 주제 생성**

1. AWS 콘솔 → **SNS → 주제 → 주제 생성**
2. 주제 이름: cloudwatch-alarm-topic
3. **구독 추가**
    - 프로토콜: **Email**
    - 엔드포인트: 본인 이메일 주소 입력
4. 메일함에서 **[Confirm subscription]** 클릭
    
    → “Confirmed” 메시지 확인
    

---

## **💻 5. EC2 인스턴스 생성**

| **항목** | **설정값** |
| --- | --- |
| AMI | Amazon Linux 2023 |
| 인스턴스 유형 | t3.micro |
| IAM 역할 | CWAgentEC2Role |
| 네트워크 | 기본 VPC 선택 (필요 시 새 VPC 생성) |
| 보안 그룹 | SSH 허용 (My IP, Port 22) |

> ⚠️ VPC가 없다는 메시지가 나온 경우
> 

> → VPC 대시보드 → “VPC 생성” → “기본 VPC 생성” 버튼 클릭
> 

---

## **🧠 6. CloudWatch Agent 설정 및 실행**

### **(1) EC2 접속**

AWS 콘솔 → EC2 → 인스턴스 → “연결” → **Session Manager** 사용

### **(2) Agent 설치**

```
sudo yum install -y amazon-cloudwatch-agent
```

### **(3) 기본 설정 파일 생성**

```
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard
```

지표 항목 선택: cpu, mem, disk, logs

결과 파일:

/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

### **(4) Agent 시작**

```
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
```

✅ “Configuration validation succeeded” 문구가 뜨면 성공

---

## **📊 7. CloudWatch 콘솔에서 지표 확인**

1. CloudWatch 콘솔 → **지표(Metrics)**
2. “사용자 지정 네임스페이스” → CWAgent 클릭
3. “InstanceId” 기준으로 필터 → cpu_usage_user, mem_used_percent 확인
    
    → 그래프에 데이터가 표시되면 에이전트 정상 작동
    

---

## **🚨 8. CloudWatch 경보(Alarm) 생성**

### **① 지표 및 조건 지정**

| **항목** | **설정** |
| --- | --- |
| 네임스페이스 | CWAgent |
| 지표 이름 | cpu_usage_user |
| 인스턴스 ID | 해당 EC2 인스턴스 |
| 통계 | 평균 |
| 기간 | 1분 |
| 조건 | 60% 초과 (> 60) |
| 임계값 유형 | 정적 (Static) |

### **② 작업 구성**

- “경보 상태” → SNS 주제 선택
    
    → cloudwatch-alarm-topic 선택
    
    → 이메일 연결 완료
    

### **③ 경보 세부 정보 추가**

| **항목** | **값** |
| --- | --- |
| 이름 | CPU_Usage_Alarm |
| 설명 | EC2 CPU 사용률 60% 초과 시 알림 |

### **④ 미리보기 및 생성**

설정 확인 후 **[경보 생성]** 클릭

---

## **🧪 9. CPU 부하 테스트**

### **(1) 부하 발생**

```
yes > /dev/null &
```

→ [1] 2615 처럼 표시되면 CPU 부하 실행 중

→ 1~3분 내 CloudWatch에서 상태가 **OK → ALARM** 으로 변경됨

→ 이메일로 알림 수신 (제목: “ALARM: CPU_Usage_Alarm”)

### **(2) 부하 중지**

```
killall yes
```

→ 1~2분 후 CloudWatch 경보가 **정상(OK)** 으로 복귀

---

## **⚙️ 10. 주요 옵션 설명**

| **항목** | **역할** | **선택 이유** |
| --- | --- | --- |
| **임계값 유형 (Static)** | 직접 기준 지정 | CPU 수치 기반 경보용 |
| **비교 조건 (>)** | 기준보다 클 때 알람 | CPU 사용률 초과 감지 |
| **평가 기간 (1분)** | 1분 단위 데이터 반영 | 빠른 반응을 위해 |
| **SNS 알림** | 이메일 전송 | 간단하고 실습용으로 적합 |

---

## **🧩 11. 문제 해결 과정 요약**

| **문제** | **원인** | **해결 방법** |
| --- | --- | --- |
| VPC가 없다는 경고 | 기본 VPC 미존재 | VPC 대시보드 → “기본 VPC 생성” |
| 지표가 안 보임 | Agent 미실행 or IAM 권한 없음 | CWAgentEC2Role 부여 후 agent 재시작 |
| 인스턴스 접근 불가 | SSH 포트 미허용 | 보안그룹 → Inbound 규칙에 My IP, Port 22 추가 |
| 이메일 안 옴 | SNS 구독 미확인 | 이메일에서 “Confirm subscription” 클릭 |
| 경보가 바로 안 울림 | 데이터 전송 지연 | 1~3분 기다리면 정상 반영 |

---

## **✅ 12. 실습 결과 요약**

| **항목** | **결과** |
| --- | --- |
| EC2 생성 및 역할 부여 | 완료 |
| CloudWatch Agent 설치 | 완료 |
| 지표 수집 확인 | 정상 |
| CPU Alarm 설정 | 정상 |
| SNS 이메일 알림 | 정상 작동 |
| 테스트 및 복귀 | 성공 |

![스크린샷 2025-10-25 01.37.16.png](attachment:e570189c-e771-4b3f-ba4e-004f3780707b:스크린샷_2025-10-25_01.37.16.png)

![스크린샷 2025-10-25 01.37.29.png](attachment:c47d0d44-f38a-4029-8324-9b24845bcb63:스크린샷_2025-10-25_01.37.29.png)
