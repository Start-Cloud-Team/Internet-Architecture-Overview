![image.png](attachment:068a50c2-7c07-4413-9146-cb89ef10d0ee:image.png)

1. Git에서 Travis CI에 소스를 제공합니다
2. Travis CI는 소스를 받아 빌드하고 빌드 결과물을 AWS S3에 저장합니다
    (Travis CI는 저장 기능이 없으므로 CodeDeploy가 배포할 때 사용할 파일을 AWS S3에 저장한다)
    (소스 코드가 JAVA였기 때문에 Jar파일을 전달했다)  
3. AWS CodeDeploy는 빌드된 파일을 AWS S3에서 다운로드 한 후, 실행할 수 있는 장소 AWS EC2로 자동 배포한다
4. AWS EC2는 파일을 실행하여 최종적으론 SpringBoot가 실행된다
  (즉, Jar파일 안에는 SpringBoot 소스 코드가 있었다는 것을 알 수 있다

아키텍처 출처) https://blog.naver.com/ds4ouj/222804935645
