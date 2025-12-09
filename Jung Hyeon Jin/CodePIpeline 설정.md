## CodePipeline 생성
<img width="1799" height="709" alt="image" src="https://github.com/user-attachments/assets/43dd7d31-ebd0-49f3-8d28-79d29a46bf00" />
<img width="1527" height="682" alt="image" src="https://github.com/user-attachments/assets/8ed35118-10a2-4230-97bf-cc5380f24375" />
<img width="1785" height="1068" alt="image" src="https://github.com/user-attachments/assets/9df92997-7bc4-42df-a36b-7375f3855683" />
<img width="1742" height="1155" alt="image" src="https://github.com/user-attachments/assets/e52c4d47-9304-4391-93f3-0b1cef72b159" />
<img width="1145" height="1045" alt="image" src="https://github.com/user-attachments/assets/63e30204-999d-4416-9c05-4a9533e0350d" />
<img width="1145" height="1045" alt="image" src="https://github.com/user-attachments/assets/7d75bda3-bb73-4f47-9103-4d0f62dc82eb" />
<img width="1512" height="909" alt="image" src="https://github.com/user-attachments/assets/ce566176-66f4-47bc-89aa-6906be5a489e" />


## CodePipeline Build Failed - 1
<img width="1757" height="1165" alt="image" src="https://github.com/user-attachments/assets/4d31fe8a-82c8-4791-9311-e6599a254fae" />
```
코드 빌드 로그
[Container] 2025/11/13 02:37:27.430212 Running on CodeBuild On-demand
[Container] 2025/11/13 02:37:27.430223 Waiting for agent ping
[Container] 2025/11/13 02:37:27.832351 Waiting for DOWNLOAD_SOURCE
error while downloading key bWAPP-CodePipeline/SourceArti/4enCV0l, error: AccessDenied: User: arn:aws:sts::329984431650:assumed-role/bWAPP-CodeBuild-service-Role/AWSCodeBuild-c7feaf23-fe50-4b64-93a7-9ee725d0a450 is not authorized to perform: s3:GetObject on resource: "arn:aws:s3:::codepipeline-ap-northeast-2-c41ef1698e4d-4d11-8298-799724f87ae7/bWAPP-CodePipeline/SourceArti/4enCV0l" because no identity-based policy allows the s3:GetObject action
status code: 403, request id: JTJFZ0RRWKYAXPSG, host id: iPEceWnPJzZ7LqpiQ7rNzkqyHOdJgc48K7qYLth5qX2vFceAqadG32R8r7BpmtqUCts6DK1gmPYz1bI3AY/Q0XZ+fMeQDsWy8jsDDFROJ9c= for primary source and source version arn:aws:s3:::codepipeline-ap-northeast-2-c41ef1698e4d-4d11-8298-799724f87ae7/bWAPP-CodePipeline/SourceArti/4enCV0l
```

CodeBuild 실패 이유로는 CodeBuild에 S3 권한이 존재하지 않기 때문이다.

사실 CodeBuild 권한 설정을 할 때 S3 서비스를 사용하지 않을 것이기 때문에 사용할 필요가 없다고 생각했다.
하지만 CodePipeline에서 아티팩트를 설정하는 과정 속 S3에 잠시동안 저장하기 때문에 관련 권한이 필요하다.
이에 아래와 같은 권한을 bWAPP-CodeBuild-service-Role에 추가하였다.
```
{
	"Effect": "Allow",
	"Action": [
		"s3:GetObject",
		"s3:GetObjectVersion",
		"s3:GetBucketLocation",
		"s3:PutObject"
	],
	"Resource": [
		"arn:aws:s3:::codepipeline-ap-northeast-2-c41ef1698e4d-4d11-8298-799724f87ae7/*"
	]
}
```
위 권한을 부여하면 CodePipeline에서 CodeBuild가 성공하게 된다.

## CodePipeline Deploy Failed - 1
```
Image URI container named: <imageDetail.json> does not match any of the missing containers in the task definition file provided.
```
ECS 서비스가 배포할 때 Task Definition에 등록된 컨테이너 이름과, 실제 배포하려는 이미지 지정 방식이 일치하지 않을 때 발생
**여기서부터 많은 설정들을 바꿔 구체적인 원인은 파악하지 못했습니다만… 여러가지의 설정을 바꾸면서 알게 되고, 설정을 바꾼 부분을 설명하겠습니다.**

---
처음으로 돌아가서 CodeBuild를 통해 ECR에 저장되어 있는 도커 이미지를 CodePipeline을 통해 배포하는 방식으로는 두 가지가 있습니다.
- S3에 도커 이미지를 저장했다가 가져와서 배포
- 바로 ECR에 저장된 이미지를 가져와서 배포
딱 봐도 후자가 더 효율적이라고 생각하여 두 번째 방식을 택하였습니다.

### 아티팩트
앞 단계에서 진행한 내용을 파일로 압축시켜 다음 단계에 사용하는 파일을 말한다.
현재 CodePipeline에서 사용하는 아티팩트 유형은 2가지이다.

- SourceArtifact
    소스 단계를 통해 가져온 소스 코드가 저장되어 있는 아티팩트이다.
    다음 단계인 빌드에서 사용된다.
- BuildArtifact
    빌드 단계를 통해 생성된 아티팩트이다.
    배포 단계에서 사용된다.
  
아티팩트 이름은 현재 AWS에서 기본 설정 되어있는 것을 사용하였고, 다른 이름으로 된 아티팩트를 사용해도 문제는 없다.

초반에 [작업 정의의 자리 표시자 텍스트]를 imageDetail.json으로 설정하여 문제가 생겼다.
<img width="1283" height="611" alt="image" src="https://github.com/user-attachments/assets/d8e0bf9d-4003-4125-b2b7-cee710d6c61a" />
[작업 정의의 자리 표시자 텍스트]는 CodePipeline에서 AppSpec이나 배포 그룹을 설정할 때, TaskDefinition 이름이나 ARN을 나중에 동적으로 바꾸도록 하는 것이다.
task는 배포가 될 때마다 새롭게 생성된다.
하지만 빌드 과정에서는 아직 task가 만들어지지 않았기 때문에 새로 생성되는 task arn을 나중에 추가해주는 것이다.
이를 통해 새로운 task 정의를 배포할 수 있다.
이에 imageDetail.json을 만들어서 자동으로 task 업데이트 할 수 있도록 했더니 오류가 났다.
- 정확한 이유는 파악하지 못했지만 아마 imageDetail.json이 아닌 “imageDetail.json”으로 인식하고 있는 것 같다.
이 부분에 대해서는 추후에 설정할 예정이다.

현재는 [작업 정의의 자리 표시자 텍스트]를 설정하지 않은 상태로 task의 arn을 직접 codebuild에 입력하는 형식이다.

## imageDetail.json 
```
{
  "imageDetails": [
    {
      "imageDigest": "sha256:abc123...",
      "imageTags": ["latest", "v1.0"],
      "imagePushedAt": "2025-11-15T07:00:00Z",
      "repositoryName": "Bwapp-repo"
    }
  ]
}
```
배포할 컨테이너 이미지의 전체 URI를 포함하고 있다.

비슷하게도 imagedefinitions.json 파일이 있다.
```
[
  {
    "name": "sample-app",
    "imageUri": "11111EXAMPLE.dkr.ecr.us-west-2.amazonaws.com/ecs-repo:latest"
  }
]
```

## taskdef.json
```
{
  "family": "Bwapp-taskdef",
  "executionRoleArn": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "2048",
  "containerDefinitions": [
    {
      "name": "Bwapp-container",
      "image": "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/bwapp-image:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ]
    }
  ]
}
```

## appspec.yml
```
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: "arn:aws:ecs:ap-northeast-2:123456789012:task-definition/Bwapp-taskdef:1"
        LoadBalancerInfo:
          ContainerName: "Bwapp-container"
          ContainerPort: 8080
```

아래는 수정한 buildspec.yml 파일이다.
```
version: 0.2

env:
  variables: #사용할 변수 정의
    IMAGE_REPO_NAME: "bwapp-image-repo"
    IMAGE_TAG: "latest"
    ACCOUNT_ID: "329984431650"
    AWS_DEFAULT_REGION: "ap-northeast-2"

phases:
  pre_build:
    commands:
      - echo "=== PRE_BUILD ==="
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
				#ECR에 로그인 하기 위한 비밀번호 토큰 받아오기 | 도커 CLI로 받아온 ECR 토큰을 통해 로그인
				
  build:
    commands:
      - echo "=== BUILD ==="
      - docker build -t $IMAGE_REPO_NAME:$IMAGE_TAG .
	      #현재 파일에 있는 내용을 도커 이미지화
      - docker tag $IMAGE_REPO_NAME:$IMAGE_TAG $ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG
				#도커 이미지에 태그 붙이기

  post_build:
    commands:
      - echo "=== PUSH IMAGE ==="
      - docker push $ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG
				#생성한 도커 이미지 ECR로 푸시
				
      - echo "=== CREATE imageDetail.json (CodeDeploy B/G) ==="
	      #BuilcArtiface로 출력할 이미지 관련 json 파일 만들기 (11.15 사용X)
      - |
        cat <<EOF > imageDetail.json
        [
          {
            "name": "Bwapp-container",
            "imageUri": "$ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG"
          }
        ]
        EOF

      - echo "=== CREATE taskdef.json ==="
	      #BuilcArtiface로 출력할 task 관련 json 파일 만들기
      - |
        cat <<EOF > taskdef.json
        {
          "family": "Bwapp-taskdef",
          "executionRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/ecsTaskExecutionRole",
          "networkMode": "awsvpc",
          "requiresCompatibilities": ["FARGATE"],
          "cpu": "256",
          "memory": "2048",
          "containerDefinitions": [
            {
              "name": "Bwapp-container",
              "image": "$ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG",
              "essential": true,
              "portMappings": [
                {
                  "containerPort": 8080,
                  "protocol": "tcp"
                }
              ]
            }
          ]
        }
        EOF

      - echo "=== CREATE appspec.yml ==="
	      #BuilcArtiface로 출력할 배포 방식 및 리소스 관련 json 파일 만들기
      - |
        cat <<EOF > appspec.yml
        version: 0.0
        Resources:
          - TargetService:
              Type: AWS::ECS::Service
              Properties:
                TaskDefinition: "arn:aws:ecs:ap-northeast-2:329984431650:task-definition/Bwapp-tasks:18"
                LoadBalancerInfo:
                  ContainerName: "Bwapp-container"
                  ContainerPort: 8080

        EOF

artifacts:
  files:
    - imageDetail.json
    - taskdef.json
    - appspec.yml
```

- 파이프라인 소스 단계 편집
<img width="774" height="829" alt="image" src="https://github.com/user-attachments/assets/1c498fe0-e582-4710-badc-d2aa3855401e" />

파이프라인 빌드 단계 편집
<img width="1755" height="1125" alt="image" src="https://github.com/user-attachments/assets/cc718567-0b0d-4402-8396-67850c28be47" />

파이프라인 배포 단계 편집
<img width="1757" height="1236" alt="image" src="https://github.com/user-attachments/assets/c3d37972-252c-4762-a429-41cc64fa665f" />

<img width="1519" height="545" alt="image" src="https://github.com/user-attachments/assets/b0412890-e039-48a0-b42a-72add526b13c" />
