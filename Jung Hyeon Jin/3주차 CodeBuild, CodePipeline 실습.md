AWS CodeBuild?

: 코드 작성 및 테스트


사용해야하는 이유? 

: 자체 빌드 서버를 프로비저닝, 관리 및 확장할 필요 없이 소스 코드의 위치를 지정하고 빌드 설정을 선택하기만 하면, 코드를 컴파일하고, 테스트하여 패키징하기 위한 빌드 스크립트를 실행한다.


이점

설정 또는 유지 관리 불필요 - 자체 빌드 서버를 설정, 관리, 패칭할 필요가 없다.

용량 규모 조정 - 용량을 자동으로 확장할 수 있어 빌드가 실행 대기열에 대기하기 않는다.

사용량별 결제 - 구축하는 데 사용한 시간만큼만 요금을 지불하면 된다.

사전 패키징된 빌드 환경 - 사전 패키징된 구축 환경 또는 자체 구축 환경을 사용하고 사용자의 키로 아티첵트를 암호화할 수 있다.


사용 사례

지속적 통합 및 전달(CI/CD) 파이프라인 자동화

  여러 배포 환경을 통해 코드 변경을 촉진하는 완전자동형 소프트웨어 릴리스 프로세스를 만든다.
  
  *소프트웨어 릴리스 프로세스 : 소프트웨어 설계, 개발, 테스트, 배포, 과정 절차

빌드 서버 관리의 복잡성 제거

  CodeBuild에서 CI/CD 툴 중 하나인 Jenkins 빌드 작업을 실행하면 Jenkins 빌드 노드 구성 및 관리의 필요성이 없어진다.
  
  GitHub에서 호스팅되는 소스 코드 구축


GitHub 리포지토리를 사용해 소프트웨어 구축을 자동 시작하고 결과를 GitHub에 게시할 수 있다.



AWS CodePipeline?

: 빠르고 안정적인 업데이트를 위한 지속적 전달 파이프라인 자동화


이점

서버 설정 또는 프로비저닝 불필요 - 소프트웨어 릴리스 프로세스를 모델링하고, 서버를 설정하거나 프로비저닝할 필요성을 줄일 수 있다.

소프트웨어 릴리스 프로세스 간소화 - AWS Management Console 또는 AWS Command Line Interface(CLI)를 사용하여 소프트웨어 릴리스 프로세스 단계를 정의한다.

새로운 기능의 빠른 출시 - 피드백을 반복하고 각 코드 변경을 테스트하여 버그를 포착하는 새로운 기능을 신속하게 릴리스할 수 있다.

필요에 맞게 조정 - 릴리스 프로세스의 모든 단계에서 자체 플러그인 또는 사전 구축된 플러그인을 사용할 수 있다.


사용 사례

파이프라인 구조 정의 - 기존 파이프라인을 업데이트하고 선언적 JSON 문서로 새 파이프라인을 생성하기 위한 템플릿을 제공하고 있다.

이벤트 알림 수신 - 상태 메시지와 이벤트 소스에 대한 링크를 제공하는 Amazon Simple Notification Service(Amazon SNS)로 파이프라인에 영향을 미치는 이벤트를 모니터링한다.

엑세스 제어 및 권한 부여 - AWS Identity and Access Management(IAM)를 사용하여 릴리스 워크플로를 변경하고 제어할 수 있는 사람을 관리한다.

사용자 지정 시스템 통합 - AWS CodePipeline 오픈 소스 에이전트를 사용자의 서버와 통합하여 사용자 지정 작업을 등록하고 파이프라인에 서버를 연결한다.




CodeBuild 생성
<img width="1212" height="942" alt="image" src="https://github.com/user-attachments/assets/72b53d0d-904a-4564-bf5e-809c111df7e0" />

CodeBuild 결과 로그
<img width="1671" height="422" alt="image" src="https://github.com/user-attachments/assets/99500322-0207-4efa-93e2-1499518f06c1" />
<img width="928" height="198" alt="image" src="https://github.com/user-attachments/assets/db27ac7a-bc30-4a84-b043-77bc1da4f64b" />



파이프라인 생성

1. AWS CodePipeline 콘솔에 들어간다.
   
2. AWS Region selctor에서 빌드 프로젝트에 있는 AWS 리소스를 선택한다.
   
  CodePipeline과 CodeBuild region을 같도록 한다.

3. [파이프라인 생성]을 눌러 파이프라인을 만든다. 
<img width="1456" height="333" alt="image" src="https://github.com/user-attachments/assets/1b3133da-499f-444b-b021-55dd1253df36" />

Category 선택 - 파이프라인의 목적

  Deployment(CD) : 소스 코드를 빌드하고 컨테이너 이미지화 하여 클라우드 환경에 실제 애플리케이션을 실행
  
  Continuous Integration(CI) : 코드 변경 사항을 지속적으로 빌드, 테스트, 통합
  
  Automation(자동화) : 반복적인 작업이나 인프라 관리 등을 자동화
  
  사용자 지정 파이프라인 빌드 : 위 카테고리에 속하지 않는 특정 조건에 맞춘 파이프라인의 모든 단계를 사용자에 맞게 구성
  
테스트를 위해 사용자 지정 파이프라인 빌드를 선택하였다.

<img width="1334" height="1036" alt="image" src="https://github.com/user-attachments/assets/9df5a846-c482-49e0-8d48-d4b4f58714ab" />

4. pipeline과 Role 이름을 설정한다.
   
  [새 서비스 역할] → [역할 이름]를 클릭하여 새로운 서비스 역할을 위한 이름을 설정
  
  [기존 서비스 역할]를 클릭한 뒤, CodePipeline 서비스 역할을 선택

<img width="957" height="708" alt="image" src="https://github.com/user-attachments/assets/59a652e4-2538-4649-b654-9af004d4cc37" />

5. 아티팩트 스토어 항목에서 다음 중 하나를 선택한다.
   
  [기본 위치]을 선택하면 선택한 AWS region에서 파이프라인에 지정된 기본 아티팩트 저장소를 사용

  [사용자 지정 위치]를 설정하면 파이프라인과 동일한 AWS region에 이미 생성한 기존 아티팩트 저장소를 사용
  

6. 소스 스테이지 추가 페이지에서 소스 제공자로 다음 중 하나를 선택한다.
<img width="1358" height="734" alt="image" src="https://github.com/user-attachments/assets/a676c2b9-5cc5-4560-b22a-d0342d6eb536" />
  만약 소스 코드를 S3 Bucket에 저장했다면 Amazon S3의 소스 코드를 선택한다. 소스 코드의 컨테이너에 대한 이름을 선택

  소스 코드가 AWS CodeCommit 레포지토리에 저장한다면, CodeCommit를 선택한다. 리포지토리 이름을 설정한다. 빌드하길 원하는 소스코드의 버전 컨테이너인 Branch의 이름을 설정
  
  소스 코드가 GitHub repository에 저장되어 있으면, GitHub를 선택한다. [Connect to GitHub]를 선택한 뒤, 소스 코드가 포함된 저장소 이름을 설정한다. 빌드하려는 소스코드 버전이 포함된 Branch 이름을 설정
  
  테스트를 위해 AWS CodeCommit를 선택하였다.


<img width="1063" height="993" alt="image" src="https://github.com/user-attachments/assets/bffda042-7fd3-4624-997a-e3c44ad0aa18" />
7. 빌드 추가 단계 페이지에서 빌드 공급자를 [기타 빌드 공급자]로 선택한 뒤 AWS CodeBuild를 선택한다.

8. 빌드 프로젝트가 이미 존재하다면, 빌드 이름을 선택하고, 다음 단계로 넘어간다.

테스트 스테이지 추가 단계는 건너뛰기 하였다.

9. 배포 스테이지 단계 페이지에서 다음과 같이 진행하였다.
    
  빌드 출력 아티팩트는 배포하지 않으려면 [건너뛰기]를 선택
  
  빌드 출력 아티팩트를 배포하려면 [배포 공급자]에서 배포 서비스를 선택
  
  이 부분 또한 건너뛰었다.

10. Review 페이지에서 설정을 확인한 뒤 [파이프라인 생성]를 선택한다.
