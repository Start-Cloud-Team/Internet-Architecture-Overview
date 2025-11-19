# 자료조사 : AWS CodeBuild란?


> ***AWS CodeBuild란 뭔가요?***
> 

**클라우드의 완전관리형 빌드 서비스임.**

***그럼 이거 뭐해요?***

- 소스 코드를 컴파일
- 단위 테스트를 실행
- 배포할 준비가 된 아티팩트를 생성

***이거 쓰면 무슨 이점이 있나요?***

- 완전 관리형 - 빌드 서버를 직접 설정하고, 패치 및 업데이트를 적용하고, 관리할 필요가 없음
- 온디맨드 - 빌드 요구 사항을 충족하기 위해 요구에 따라 크키가 조정됨.
- 즉시 사용 가능 - 널리 사용되는 프로그래밍 언어에 맞게 사전 구성된 빌드 환경 제공

***실행 가능한 환경은 어디인가요?***

AWS CodeBuild 또는 AWS CodePipeline 콘솔을 사용하여서 실행 가능

AWS CLI 또는 SDK를 사용해서 실행을 자동화하는 것 역시 가능.

***그래서 이거 어떻게 작동한다고요?***

- [그림 1] CodeBuild를 사용해 빌드를 실행할 때 나타나는 현상
    
    ![image2.png](images/image2.png)
    
1. 입력으로 빌드 프로젝트와 함께 CodeBuild를 제공해야함.
    - 빌드 프로젝트 포함 요소 : 소스 코드를 가져올 위치, 사용할 빌드 환경, 실행할 빌드 명령 및 빌드 출력을 저장할 위치를 비롯한 빌드 실행 방법에 대한 정보가 포함되어 있어야함.
        - 빌드 환경 : CodeBuild가 빌드를 실행하는데 사용하는 운영 체제, 프로그래밍 언어 런타임 도구의 조합
    - 추가 참고 자료
    https://docs.aws.amazon.com/ko_kr/codebuild/latest/userguide/create-project.html
    https://docs.aws.amazon.com/ko_kr/codebuild/latest/userguide/build-env-ref.html
2. CodeBuild가 빌드 프로젝트를 사용해 빌드 환경 생성
3. CodeBuild가 빌드 환경에 소스 코드를 다운로드 한 후, 빌드 프로젝트에 정의되거나 소스 코드에 직접 포함된 빌드 사양을 사용.
    1. *buildspec -* CodeBuild가 빌드를 실행하는데 사용하는 YAML 형식의 빌드 명령 및 관련 설정의 모음.
4. 빌드 출력이 있으면 빌드 환경에서 출력을 S3 버킷에 업로드
5. 빌드가 실행되는 동안 빌드 환경이 정보를 CodeBuild 및 Amazon CloudWatch Logs에 전송
    1. 빌드가 실행되는 동안 AWS CodeBuild 콘솔 AWS CLI 또는 AWS SDKs를 사용해 CodeBuild에서 요약된 빌드 정보를 가져올 수 있음.
    Amazon CloudWatch Logs 자세한 빌드 정보를 가져올 수 있음.
