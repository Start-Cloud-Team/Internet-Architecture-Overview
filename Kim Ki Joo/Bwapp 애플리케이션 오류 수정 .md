# 2025-11-15 자료 : Bwapp 애플리케이션 오류 수정

구분: 자료(조사)
진행일: 2025년 11월 15일
생성자: 김기주/정보보호전공
생성 일시: 2025년 11월 15일 오후 2:29

> ***“Bwapp 애플리케이션 사용중에 배포 후에 성공은 했지만, 애플리케이션 내에서의 설정 값과 현재 AWS Fargate 외의 문제가 발생해서 해결하는 과정입니다.”***
> 

> ***1차 오류***
> 

```python
Fatal error: Class 'mysqli' not found in /var/www/html/connect_i.php on line 23
```

<aside>

`치명적 오류 : var/www/html/connect_i.php 23번 줄에 mysqli 클래스를 찾지 못했습니다.`

</aside>

*문제 이유:* php:5.6-apache 베이스 이미지에 mysqli PHP 확장(Extension)이 설치되어 있지 않기 때문

**해결 방법 :** Dockerfile에 mysqli 확장을 설치하는 명령어를 추가

```python
# 베이스 이미지
FROM php:5.6-apache

# --- Step0. DB PHP 확장 설치 ---
# bWAPP가 MySQL DB에 연결하기 위해 mysqli 확장이 필요합니다.
RUN docker-php-ext-install mysqli

# **Step 1: Apache가 8080 포트를 리스닝하도록 설정**
# 이 명령어는 Apache 설정 파일(ports.conf)의 80번 포트 리스닝 부분을 8080으로 변경합니다.
RUN sed -i 's/Listen 80/Listen 8080/g' /etc/apache2/ports.conf && \
    # default-ssl.conf에도 8080이 사용되도록 수정 (선택적)
    sed -i 's/<VirtualHost \*:443>/<VirtualHost \*:8080>/g' /etc/apache2/sites-available/default-ssl.conf
    
# 웹 루트 디렉토리로 코드 복사
COPY . /var/www/html/

# 웹 서버 실행 사용자(www-data)에게 디렉토리 권한 부여
RUN chown -R www-data:www-data /var/www/html/ && \
    chmod -R 755 /var/www/html/ && \
    # db 디렉터리에만 그룹 쓰기 권한(775)을 추가로 부여 
    chmod -R 775 /var/www/html/db

# **Step 2: 노출 포트를 8080으로 변경**
# 컨테이너가 8080 포트를 노출하도록 명시
EXPOSE 8080

# 컨테이너 시작 시 Apache 실행
CMD ["apache2-foreground"]
```

> ***2차 오류***
> 

```python
Warning: mysqli::mysqli(): (HY000/2002): No such file or directory in /var/www/html/connect_i.php on line 23
Connection failed: No such file or directory
```

*문제 이유 :* Bwapp파일 안에 배포된 파일 안에 DB로 연결할 수 있는 디렉토리가 없음.

해결 방안 : 테스크 정의 / 파일 수정

- 테스크 정의 : Bwapp-taskdef로 재생성 (배포 불가로 인한)
    
    ![스크린샷 2025-11-15 오후 3.24.24.png](2025-11-15%20%EC%9E%90%EB%A3%8C%20Bwapp%20%EC%95%A0%ED%94%8C%EB%A6%AC%EC%BC%80%EC%9D%B4%EC%85%98%20%EC%98%A4%EB%A5%98%20%EC%88%98%EC%A0%95/7425d419-cc74-48d9-9a3a-25f07cea4a55.png)
    
    - DB용 컨테이너 새로 생성
    - 필수 컨테이너 : 예  (배포시 바로 같이 돌아가야하니깐.)
    
    ![스크린샷 2025-11-15 오후 3.24.27.png](2025-11-15%20%EC%9E%90%EB%A3%8C%20Bwapp%20%EC%95%A0%ED%94%8C%EB%A6%AC%EC%BC%80%EC%9D%B4%EC%85%98%20%EC%98%A4%EB%A5%98%20%EC%88%98%EC%A0%95/fbd8197a-c1cc-421d-8b98-2cc12e3082cf.png)
    
    - 환경 변수(evn) : 
    키 : 값
    - MYSQL_ROOT_PASSWORD : BwappSCT
    - MYSQL_DATABASE : bwapp
    - MYSQL_USER : root
    
    ![스크린샷 2025-11-15 오후 3.45.27.png](2025-11-15%20%EC%9E%90%EB%A3%8C%20Bwapp%20%EC%95%A0%ED%94%8C%EB%A6%AC%EC%BC%80%EC%9D%B4%EC%85%98%20%EC%98%A4%EB%A5%98%20%EC%88%98%EC%A0%95/264567f0-8e22-4676-ab91-cf33aaaf29e0.png)
    
    - 볼륨 추가 (Fargate는 일회성이기에 저장을 위해서 볼륨을 생성하고 EFS로 전송하는 것으로 설정)
    - 이름 : mysql-data
    - 구성 유형 : 작업 정의 생성 시 구성
    - 볼륨 유형 : EFS
    - 파일 시스템 ID : Bwapp-EFS-sct
    - 루트 디렉터리 :  / (기본값 사용)
    - 액세스 포인트 ID : Bwapp-EFS-ap
    
    ![스크린샷 2025-11-15 오후 3.40.28.png](2025-11-15%20%EC%9E%90%EB%A3%8C%20Bwapp%20%EC%95%A0%ED%94%8C%EB%A6%AC%EC%BC%80%EC%9D%B4%EC%85%98%20%EC%98%A4%EB%A5%98%20%EC%88%98%EC%A0%95/78d60411-4cbd-4025-aab1-125655399c30.png)
    
    - 액세스 포인트를 사용하기 위해서는 [전송 암호화]를 활성화 해야해서 활성화 했다.
    - 액세스 포인트 왜 쓰는거죠?
        
        현재 우리 애플리케이션 Bwapp 는 PHP 5.8을 사용하는 중이기에 Mysql 역시 5.7 버전으로
        다운그레이드 되어 있는 상태이다. 근데 mysql:5.7 컨테이너는 root 사용자가 아니라, mysql 이라는
        사용자(대개 UID 999)로 실행됨.
        EFS는 기본적으로 root(UID 0) 소유라 mysql 사용자가 root 소유의 폴더에 데이터를 쓰려고 할 때
        권한 오류가 발생할 가능성이 있기 때문에 사용합니다.
        
    
    - EFS(EC2용 관리 파일 스토리지)
    
    ![스크린샷 2025-11-15 오후 3.17.58.png](2025-11-15%20%EC%9E%90%EB%A3%8C%20Bwapp%20%EC%95%A0%ED%94%8C%EB%A6%AC%EC%BC%80%EC%9D%B4%EC%85%98%20%EC%98%A4%EB%A5%98%20%EC%88%98%EC%A0%95/3ca9972a-1984-443b-8887-406bae1b1aac.png)
    
    - 이름 : Bwapp-EFS-sct
    - 파일 시스템 유형 : 리전
    - 자동 백업 : 활성화
    
    ![스크린샷 2025-11-15 오후 3.18.06.png](2025-11-15%20%EC%9E%90%EB%A3%8C%20Bwapp%20%EC%95%A0%ED%94%8C%EB%A6%AC%EC%BC%80%EC%9D%B4%EC%85%98%20%EC%98%A4%EB%A5%98%20%EC%88%98%EC%A0%95/d2b1d4c3-cb1d-43ef-bb48-29319da45329.png)
    
    - 대부분 기본값으로 설정했습니다.
    
    ![스크린샷 2025-11-15 오후 3.21.43.png](2025-11-15%20%EC%9E%90%EB%A3%8C%20Bwapp%20%EC%95%A0%ED%94%8C%EB%A6%AC%EC%BC%80%EC%9D%B4%EC%85%98%20%EC%98%A4%EB%A5%98%20%EC%88%98%EC%A0%95/68c466b3-5982-4470-ab49-a407595d03bd.png)
    
    - VPC : Bwapp-sct-vpc
    - 탑재 대상 : -a, -c 구역 프라이빗 서브넷
    - 보안 그룹 : Bwapp-EFS-sg
    
    ![스크린샷 2025-11-15 오후 3.22.48.png](2025-11-15%20%EC%9E%90%EB%A3%8C%20Bwapp%20%EC%95%A0%ED%94%8C%EB%A6%AC%EC%BC%80%EC%9D%B4%EC%85%98%20%EC%98%A4%EB%A5%98%20%EC%88%98%EC%A0%95/db56a240-eb84-4cd3-9b8b-fe4800331d3a.png)
    
    - 파일 시스템 정책은 보안 그룹이 있으니 패스
    
    ![스크린샷 2025-11-15 오후 3.23.01.png](2025-11-15%20%EC%9E%90%EB%A3%8C%20Bwapp%20%EC%95%A0%ED%94%8C%EB%A6%AC%EC%BC%80%EC%9D%B4%EC%85%98%20%EC%98%A4%EB%A5%98%20%EC%88%98%EC%A0%95/84ae3b74-5ab2-4f64-9c4a-b50bff10a500.png)
    
    ![스크린샷 2025-11-15 오후 3.23.04.png](2025-11-15%20%EC%9E%90%EB%A3%8C%20Bwapp%20%EC%95%A0%ED%94%8C%EB%A6%AC%EC%BC%80%EC%9D%B4%EC%85%98%20%EC%98%A4%EB%A5%98%20%EC%88%98%EC%A0%95/848c2962-4fba-4f3d-a308-328319b9b66c.png)
    
    ![스크린샷 2025-11-15 오후 3.23.19.png](2025-11-15%20%EC%9E%90%EB%A3%8C%20Bwapp%20%EC%95%A0%ED%94%8C%EB%A6%AC%EC%BC%80%EC%9D%B4%EC%85%98%20%EC%98%A4%EB%A5%98%20%EC%88%98%EC%A0%95/d7ba7c75-da8e-461c-8ea3-1c8443b49ae9.png)
    
    - TaskDef EFS 액세스 포인트 설정
    
    ![스크린샷 2025-11-15 오후 3.37.00.png](2025-11-15%20%EC%9E%90%EB%A3%8C%20Bwapp%20%EC%95%A0%ED%94%8C%EB%A6%AC%EC%BC%80%EC%9D%B4%EC%85%98%20%EC%98%A4%EB%A5%98%20%EC%88%98%EC%A0%95/618fd3f6-941a-437a-9d2b-a1d867cf21c5.png)
    
    ![스크린샷 2025-11-15 오후 3.37.05.png](2025-11-15%20%EC%9E%90%EB%A3%8C%20Bwapp%20%EC%95%A0%ED%94%8C%EB%A6%AC%EC%BC%80%EC%9D%B4%EC%85%98%20%EC%98%A4%EB%A5%98%20%EC%88%98%EC%A0%95/d4265825-960b-435d-b3f1-a111e8e73d2b.png)
    
    - EFS sg 설정
    
    ![스크린샷 2025-11-15 오후 4.27.15.png](2025-11-15%20%EC%9E%90%EB%A3%8C%20Bwapp%20%EC%95%A0%ED%94%8C%EB%A6%AC%EC%BC%80%EC%9D%B4%EC%85%98%20%EC%98%A4%EB%A5%98%20%EC%88%98%EC%A0%95/585db1f6-803d-4e5b-8508-391ec18695ea.png)
    
    - 인바운드 규칙
    - 들어오는 NFS TCP (2049) ECS Sg로 들어오는 모든 접근 허용
    
    ![스크린샷 2025-11-15 오후 4.27.22.png](2025-11-15%20%EC%9E%90%EB%A3%8C%20Bwapp%20%EC%95%A0%ED%94%8C%EB%A6%AC%EC%BC%80%EC%9D%B4%EC%85%98%20%EC%98%A4%EB%A5%98%20%EC%88%98%EC%A0%95/ed20a611-de10-49d5-8a63-c1d55f6a9ea6.png)
    
    - 아웃바운드 규칙
    - 모든 트래픽 허용

- admin/setting.php

```python
<?php

/*

bWAPP, or a buggy web application, is a free and open source deliberately insecure web application.
It helps security enthusiasts, developers and students to discover and to prevent web vulnerabilities.
bWAPP covers all major known web vulnerabilities, including all risks from the OWASP Top 10 project!
It is for security-testing and educational purposes only.

Enjoy!

Malik Mesellem
Twitter: @MME_IT

bWAPP is licensed under a Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License (http://creativecommons.org/licenses/by-nc-nd/4.0/). Copyright © 2014 MME BVBA. All rights reserved.

*/

// Database connection settings
$db_server = "mysql-db"; //'localhost'에서 변경
$db_username = "root"; // 변경사항 X
$db_password = "BwappSCT"; // ''에서 변경
$db_name = "bwapp"; //'Bwapp'에서 변경

// SQLite database name
$db_sqlite = "db/bwapp.sqlite";

// SMTP settings
$smtp_sender = "bwapp@mailinator.com";
$smtp_recipient = "bwapp@mailinator.com";
$smtp_server = "";

// A.I.M.
// A.I.M., or Authentication Is Missing, is a no-authentication mode
// It can be used for testing web scanners and crawlers
// Steps to crawl all pages, and to detect all vulnerabilities without authentication:
//   1. Change the IP address(es) in this file to the IP address(es) of your tool(s)
//   2. Point your web scanners, crawlers or attack tools to this URL: http://[bWAPP-IP]/bWAPP/aim.php
//   3. Push the button: all hell breaks loose...
$AIM_IPs = array("6.6.6.6", "6.6.6.7", "6.6.6.8", "10.0.1.66");
$AIM_subnet = "6.6.6.0/30";
//
// Add here the files that could break bWAPP or your web server in the A.I.M. mode
$AIM_exclusions = array("aim.php", "ba_logout.php", "cs_validation.php", "csrf_1.php", "http_verb_tampering.php", "ldap_connect.php", "ldapi.php", "portal.php", "sm_dos_2.php", "sm_obu_files.php");

// Evil bee mode
// All bWAPP security levels are bypassed in this mode by using a fixed cookie (security_level: 666)
// It can be combined with the A.I.M. mode, your web scanner will ONLY detect the vulnerabilities
// Evil bees are HUNGRY :)
// Possible values: 0 (off) or 1 (on)
$evil_bee = 0;

// Static credentials
// These credentials are used on some PHP pages
$login = "bee";
$password = "bug";

?>
```

> ***3차 오류***
> 
- 오류 : 새 tasdef 후 배포가 되지 않음. (필수 컨테이너 이상, mysql-db)
- 예상 원인 : 아마도 ecs 테스크 역할에 EFS 관련 정책이 빠져있을 수 있기 때문에 확인을 위해서 삽입.
- 외에도 Taskdef에 mysql-db 컨테이너 로깅 추가함.
- 오류 로그
    
    ```python
    2025년 11월 15일, 16:55
    [Sat Nov 15 07:55:33.728502 2025] [mpm_prefork:notice] [pid 1] AH00169: caught SIGTERM, shutting down
    Bwapp-container
    2025년 11월 15일, 16:55
    chown: changing ownership of '/var/lib/mysql': Operation not permitted
    mysql-db
    2025년 11월 15일, 16:55
    chown: changing ownership of '/var/lib/mysql/': Operation not permitted
    mysql-db
    2025년 11월 15일, 16:55
    2025-11-15 07:55:33+00:00 [Note] [Entrypoint]: Entrypoint script for MySQL Server 5.7.44-1.el7 started.
    mysql-db
    2025년 11월 15일, 16:55
    [Sat Nov 15 07:55:32.360328 2025] [mpm_prefork:notice] [pid 1] AH00163: Apache/2.4.25 (Debian) PHP/5.6.40 configured -- resuming normal operations
    Bwapp-container
    2025년 11월 15일, 16:55
    [Sat Nov 15 07:55:32.360598 2025] [core:notice] [pid 1] AH00094: Command line: 'apache2 -D FOREGROUND'
    ```
    
    - 발생 이유
    1. mysql-db 컨테이너는 시작할 때 root(관리자) 권한으로 실행됩니다.
    2. 컨테이너의 시작 스크립트는 /var/lib/mysql 폴더의 소유자를 mysql 사용자(UID 999)로 변경하기 위해 chown 명령을 실행합니다.
    3. **하지만** 우리가 설정한 EFS **액세스 포인트**가 "이 폴더의 소유자는 무조건 **UID 999**여야 한다"라고 **강제**하고 있습니다.
    4. EFS는 root 사용자가 이 소유권을 변경하려는 시도( chown 명령)를 "허가되지 않은 작업(Operation not permitted)"으로 보고 **차단**합니다.
    5. chown 명령이 실패하자, mysql-db 컨테이너 스크립트는 오류(Exit Code 1)를 내고 종료됩니다.
    6. mysql-db가 종료되자, ECS는 Bwapp-container에게도 종료 신호(SIGTERM)를 보냅니다.
- 해결방안
    - Taskdef 개정 3안을 json으로 만들어서 사용자를 999로 고정하고 시작.
    
    ```json
    {
        "compatibilities": [
            "EC2",
            "FARGATE",
            "MANAGED_INSTANCES"
        ],
        "containerDefinitions": [
            {
                "cpu": 0,
                "environment": [],
                "essential": true,
                "image": "329984431650.dkr.ecr.ap-northeast-2.amazonaws.com/bwapp-image-repo:latest",
                "logConfiguration": {
                    "logDriver": "awslogs",
                    "options": {
                        "awslogs-group": "/ecs/Bwapp-taskdef",
                        "awslogs-create-group": "true",
                        "awslogs-region": "ap-northeast-2",
                        "awslogs-stream-prefix": "ecs"
                    }
                },
                "mountPoints": [],
                "name": "Bwapp-container",
                "portMappings": [
                    {
                        "appProtocol": "http",
                        "containerPort": 8080,
                        "hostPort": 8080,
                        "name": "bwapp-container-8080-tcp",
                        "protocol": "tcp"
                    }
                ],
                "systemControls": [],
                "volumesFrom": []
            },
            {
                "cpu": 0,
                "environment": [
                    {
                        "name": "MYSQL_DATABASE",
                        "value": "bwapp"
                    },
                    {
                        "name": "MYSQL_ROOT_PASSWORD",
                        "value": "BwappSCT"
                    },
                    {
                        "name": "MYSQL_USER",
                        "value": "root"
                    }
                ],
                "essential": true,
                "image": "mysql:5.7",
                "logConfiguration": {
                    "logDriver": "awslogs",
                    "options": {
                        "awslogs-group": "/ecs/Bwapp-taskdef",
                        "awslogs-create-group": "true",
                        "awslogs-region": "ap-northeast-2",
                        "awslogs-stream-prefix": "ecs"
                    }
                },
                "memory": 1024,
                "mountPoints": [
                    {
                        "containerPath": "/var/lib/mysql",
                        "readOnly": false,
                        "sourceVolume": "mysql-data"
                    }
                ],
                "name": "mysql-db",
                "portMappings": [],
                "systemControls": [],
                "user": "999",
                "volumesFrom": []
            }
        ],
        "cpu": "1024",
        "enableFaultInjection": false,
        "executionRoleArn": "arn:aws:iam::329984431650:role/ecsTaskExecutionRole",
        "family": "Bwapp-taskdef",
        "memory": "3072",
        "networkMode": "awsvpc",
        "placementConstraints": [],
        "registeredAt": "2025-11-15T08:07:46.385Z",
        "registeredBy": "arn:aws:iam::329984431650:user/KimKiJoo",
        "requiresAttributes": [
            {
                "name": "ecs.capability.execution-role-awslogs"
            },
            {
                "name": "com.amazonaws.ecs.capability.ecr-auth"
            },
            {
                "name": "com.amazonaws.ecs.capability.docker-remote-api.1.17"
            },
            {
                "name": "ecs.capability.execution-role-ecr-pull"
            },
            {
                "name": "com.amazonaws.ecs.capability.docker-remote-api.1.18"
            },
            {
                "name": "ecs.capability.task-eni"
            },
            {
                "name": "com.amazonaws.ecs.capability.docker-remote-api.1.29"
            },
            {
                "name": "com.amazonaws.ecs.capability.logging-driver.awslogs"
            },
            {
                "name": "ecs.capability.efsAuth"
            },
            {
                "name": "com.amazonaws.ecs.capability.docker-remote-api.1.19"
            },
            {
                "name": "ecs.capability.efs"
            },
            {
                "name": "com.amazonaws.ecs.capability.docker-remote-api.1.25"
            }
        ],
        "requiresCompatibilities": [
            "FARGATE"
        ],
        "revision": 3,
        "runtimePlatform": {
            "cpuArchitecture": "X86_64",
            "operatingSystemFamily": "LINUX"
        },
        "status": "ACTIVE",
        "taskDefinitionArn": "arn:aws:ecs:ap-northeast-2:329984431650:task-definition/Bwapp-taskdef:3",
        "volumes": [
            {
                "efsVolumeConfiguration": {
                    "authorizationConfig": {
                        "accessPointId": "fsap-0b75ae6a7f316840c",
                        "iam": "DISABLED"
                    },
                    "fileSystemId": "fs-0845cf66c4a9a262f",
                    "rootDirectory": "/",
                    "transitEncryption": "ENABLED"
                },
                "name": "mysql-data"
            }
        ],
        "tags": []
    }
    ```
    

> 문제 상황 4
> 
- EFS 루트 디렉토리 경로 설정 오류.
- 오류 설명
    
    이것은 EFS 액세스 포인트의 **"루트 디렉터리 경로"** 설정 때문에 발생합니다.
    
    1. 컨테이너는 user: "999" 설정으로 mysql 사용자로 정상 실행되었습니다.
    2. mysql 사용자가 EFS(액세스 포인트 경유)에 /var/lib/mysql로 연결을 시도했습니다.
    3. 액세스 포인트의 "루트 디렉터리 경로"가 /로 설정되어 있었습니다.
    4. EFS 파일 시스템의 / 디렉터리는 **기본 소유자가 root (UID 0)** 입니다.
    5. 액세스 포인트의 "루트 디렉터리 **생성** 권한"(999:999로 설정한 것)은 **해당 디렉터리가 없을 때만** 적용됩니다. /는 이미 존재하므로 이 권한이 적용되지 않았습니다.
    
    **결과:** mysql 사용자(999)가 root 소유의 디렉터리에 쓰기를 시도하다 "Permission denied (권한 거부)" 오류가 발생했습니다.
    
- 해결하기
    
    > 액세스 포인트 재설정
    > 
    - *EFS 콘솔 > "액세스 포인트"로 이동합니다.*
    - **"액세스 포인트 생성"**을 클릭합니다.*
    - *파일 시스템 ID: fs-0845... (기존과 동일한 EFS 선택)*
    - *루트 디렉터리 경로: /mysql (이것이 핵심입니다)*
    - *POSIX 사용자 ID: 999*
    - *그룹 ID: 999*
    - *루트 디렉터리 생성 권한:*
        - *소유자 사용자 ID: 999*
        - *소유자 그룹 ID: 999*
        - *권한: 0755*
    - *액세스 포인트를 생성합니다.*
    

> 문제 상황 5
> 

```yaml
Warning: mysqli::mysqli(): php_network_getaddresses: getaddrinfo failed: Name or service not known in /var/www/html/connect_i.php on line 23

Warning: mysqli::mysqli(): (HY000/2002): php_network_getaddresses: getaddrinfo failed: Name or service not known in /var/www/html/connect_i.php on line 23
Connection failed: php_network_getaddresses: getaddrinfo failed: Name or service not known
```

- 오류가 계속 발생해서 그냥 오픈소스 변경하기로 결정.