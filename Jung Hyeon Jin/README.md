<img width="1407" height="872" alt="image" src="https://github.com/user-attachments/assets/3a936042-3910-4b47-a5ce-0c8b391a0924" />



전반적인 흐름 : 개발자가 Github에 코드 푸시 → Github Actions가 빌드 → Docker 이미지를 레지스트리에 올림 → AWS Fargate에 자동 배포

1. 개발 단계
개발자는 Intellij에서 코드를 작성한다.
코드를 통해 deploy.yml 파일을 만든다.    
  deploy.yml : GitHub Actions에서 어떤 순서로 빌드 및 배포를 수행할지 정의하는 워크플로우 설정 파일  

amazon-corretto-17 
: AWS에서 제공하는 무료 오픈소스 JDK(Java Development Kit) 버전으로, Java를 실행하고 개발하기 위한 환경이다.
자바 런타임 환경(JDK 17)을 GitHub Actions가 받아서 빌드 시 사용

    
2. CI/CD 자동화 단계
GitHub Repository : 코드 저장소
개발자가 push 하면, GitHub Actions가 웹훅(hook) 을 통해 자동 실행된다.

GitHub Actions (Backend CI/CD with GitHub Actions) : CI/CD 자동화 도구.
- 하는 일 :
  1. JDK 세팅 (amazon-corretto-17)
  2. 코드 빌드 및 테스트
  3. Docker 이미지 빌드
  4. 이미지 레지스트리에 업로드(publish)
  5. AWS Fargate로 배포(deploy)
모든 작업은 deploy.yml에 정의되어 있다.

Container Registry
빌드된 Docker 이미지를 저장하는 레지스트리 (예: AWS ECR, Docker Hub 등)
이후 Fargate가 여기서 이미지를 가져온다.
    
    
3. 배포 단계
AWS Cloud 내부의 Virtual Private Cloud (VPC) : AWS 내부 네트워크 공간.
여기서 여러 서비스(organization, customer, salesOrder)가 구동된다.

AWS Fargate
컨테이너화된 애플리케이션을 실행하고 관리하는 서비스로, 로드 테스트를 위한 가상 사용자를 생성하고 관리한다.
GitHub Actions가 배포 시점에 AWS Fargate에게 “새 이미지로 컨테이너를 실행하라”고 명령한다.

아키텍처 출처 : https://www.park108.net/log/1645454698275
AWS Fargate는 Container Registry에서 새 이미지를 pull 해서 실행한다.

서비스들 (organization service, customer service, salesOrder service)
각각 백엔드의 마이크로서비스들이다.
각 서비스는 자신만의 DB 테이블(organization tables, customer tables, sales_order tables)과 연결되어 있다.
