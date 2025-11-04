# 🧱 AWS CodeBuild + ECR 프로젝트 설정 기록

## 🗓️ 진행 개요
- **프로젝트명**: `LJH_1`
- **리전**: `ap-northeast-2 (서울)`
- **목표**: GitHub에 있는 bWAPP 프로젝트를 Docker 이미지로 빌드하여
  Amazon ECR(AWS Elastic Container Registry)에 자동 푸시.

---

## 🚀 1. ECR(Elastic Container Registry) 설정

### 📌 과정 요약
1. **AWS Console → ECR → 리포지토리 생성**
   - 이름: `ljh_1`
   - 가시성: **비공개 (Private)**
   - 암호화: 기본 (AES-256)
   - 스캔 옵션: 선택 안 함 (기본)
   - 푸시 명령 예시 자동 생성됨

### 📋 결과
리포지토리 URI 예시:
```
329984431650.dkr.ecr.ap-northeast-2.amazonaws.com/ljh_1
```

> ✅ `ap-northeast-2`는 서울 리전이므로 올바름
> (즉, `...amazonaws.com` 뒤의 `ap-northeast-2`는 변경할 필요 없음)

---

## 🧩 2. CodeBuild 프로젝트 생성

### 설정 요약
- **프로젝트 이름**: `LJH_1`
- **소스 공급자**: GitHub
- **리포지토리 유형**: Public Repository
  (👉 `https://github.com/Start-Cloud-Team/bWAPP`)
- **환경 이미지**: Managed image
- **런타임**: Ubuntu / Standard (Docker 20.x 포함)
- **빌드 사양 파일(buildspec.yml)**: 리포지토리 루트에 위치

---

## ⚙️ 3. `buildspec.yml` 구성

```yaml
version: 0.2

env:
  variables:
    IMAGE_REPO_NAME: "ljh_1"
    IMAGE_TAG: "latest"
    AWS_DEFAULT_REGION: "ap-northeast-2"

phases:
  install:
    runtime-versions:
      docker: 20
    commands:
      - echo "==== INSTALL PHASE START ===="
      - docker --version
      - aws --version
      - echo "==== INSTALL PHASE END ===="

  pre_build:
    commands:
      - echo "==== PRE-BUILD START ===="
      - ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
      - echo "Logging in to Amazon ECR..."
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - echo "==== PRE-BUILD END ===="

  build:
    commands:
      - echo "==== BUILD START ===="
      - docker build -t $IMAGE_REPO_NAME:$IMAGE_TAG .
      - docker tag $IMAGE_REPO_NAME:$IMAGE_TAG $ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG
      - echo "==== BUILD END ===="

  post_build:
    commands:
      - echo "==== POST-BUILD START ===="
      - docker push $ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG
      - echo "Build completed successfully."
      - echo "IMAGE_URI=$ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG" > imageDetail.txt
      - echo "==== POST-BUILD END ===="

artifacts:
  files:
    - imageDetail.txt
  discard-paths: yes
```

---

## ❌ 4. 첫 번째 빌드 오류 발생

### 오류 로그 요약
```
An error occurred (AccessDeniedException) when calling the GetAuthorizationToken operation:
User: arn:aws:sts::329984431650:assumed-role/codebuild-LJH_1-service-role/...
is not authorized to perform: ecr:GetAuthorizationToken on resource: *
because no identity-based policy allows the ecr:GetAuthorizationToken action
```

### 🚨 원인 분석
- CodeBuild가 ECR에 로그인하려고 시도했지만,
- 연결된 IAM Role(`codebuild-LJH_1-service-role`)에 **ECR 권한이 없었음**

---

## 🧰 5. IAM Role 권한 수정으로 해결

### 수정 방법
1. AWS Console → IAM → Roles → `codebuild-LJH_1-service-role` 선택
2. “**권한 추가 (Attach policies)**” 클릭
3. 아래 두 정책을 연결:
   - ✅ `AmazonEC2ContainerRegistryPowerUser`
   - ✅ `AmazonS3ReadOnlyAccess` *(선택, 로그 저장용)*

---

## 🧪 6. 두 번째 빌드 (재시도)

### 로그 요약
```
Logging in to Amazon ECR...
Login Succeeded
Building Docker image...
Pushing Docker image to ECR...
Build completed successfully.
```

### ✅ 결과
- ECR 로그인 성공 (`Login Succeeded`)
- Docker 빌드 성공 (`docker build -t ljh_1:latest .`)
- 이미지 푸시 성공:
  ```
  The push refers to repository [329984431650.dkr.ecr.ap-northeast-2.amazonaws.com/ljh_1]
  latest: digest: sha256:c929458b164dab3bfe57325423c0019cb6dcb824e6653c4860aa7bb3b20a4836 size: 3459
  ```
- 최종 상태: **빌드 성공 (SUCCESS)**

---

## 🧭 7. 최종 확인

### ECR 저장소 내 확인
ECR 콘솔 → `ljh_1` 리포지토리 클릭
→ `latest` 태그로 새 이미지가 업로드됨
→ 푸시 타임스탬프 확인 가능

---

## 🧾 8. 정리 및 교훈

| 항목 | 내용 |
|------|------|
| **문제 발생 시점** | ECR 로그인 단계 (`aws ecr get-login-password`) |
| **원인** | CodeBuild IAM Role에 ECR 권한 누락 |
| **해결** | `AmazonEC2ContainerRegistryPowerUser` 정책 추가 |
| **결과** | Docker 빌드 및 ECR 푸시 성공 |
| **소요 시간** | 약 1시간 |
| **리전** | ap-northeast-2 (서울) |
| **GitHub Repo** | https://github.com/Start-Cloud-Team/bWAPP |

---

## ✅ 최종 상태 요약

- [x] ECR 리포지토리 생성 완료
- [x] CodeBuild 프로젝트 연결 완료
- [x] IAM Role 권한 수정 완료
- [x] Docker 이미지 빌드 성공
- [x] ECR 이미지 푸시 성공

---

## 🏁 결론

AWS CodeBuild와 ECR의 연동 과정에서 가장 중요한 포인트는 IAM Role 권한입니다.
빌드 자체의 오류보다 **ECR 접근 권한 누락**이 가장 흔한 실패 원인이며,
`AmazonEC2ContainerRegistryPowerUser` 정책 하나로 대부분의 문제를 해결할 수 있습니다.

이제 이후 단계로는
👉 **CodeDeploy 또는 ECS** 연동을 통해 컨테이너를 자동 배포하면 완전한 CI/CD 파이프라인이 완성됩니다.

---
