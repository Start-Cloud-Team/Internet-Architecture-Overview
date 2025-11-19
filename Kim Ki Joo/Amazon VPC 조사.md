# 2025-10-23 자료조사 : Amazon VPC 조사

- ***자료 출처***
    
    https://docs.aws.amazon.com/ko_kr/vpc/latest/userguide/what-is-amazon-vpc.html#amazon-vpc-features
    

**Amazon Virtual Private Cloud(Amazon VPC)의 약자.**

> ***그래서 이거 쓰면 뭐 할 수 있어요?***
> 
- 정의한 논리적으로 격리된 가상 네트워크에서 AWS 리소스를 사용할 수 있게 할 수 있음.

> ***장점은 뭐가 있어요?***
> 
- 이 가상 네트워크는 AWS의 확장 가능한 인프라를 사용한다는 이점이 있음.

> ***VPC의 예시 다이어그램***
> 
- *(사진)*
    
    ![image.png](images/image.png)
    
    VPC에는 리전의 각 가용성 영역에 하나의 서브넷이 있고, 각 서브넷에 EC2 인스턴스가 있고,
    VPC의 리소스와 인터넷 간의 통신을 허용하는 인터넷 게이트웨이가 있는 상황임.
    

> ***VPC는 무슨 기능이 있나요?***
> 
- *Virtual Private Cloud (VPC)*
    
    [VPC](https://docs.aws.amazon.com/ko_kr/vpc/latest/userguide/configure-your-vpc.html)는 자체 데이터 센터에서 운영하는 기존 네트워크와 아주 유사한 가상 네트워크입니다.
    VPC를 생성한 후 서브넷을 추가할 수 있습니다.
    
- *서브넷*
    
     [서브넷](https://docs.aws.amazon.com/ko_kr/vpc/latest/userguide/configure-subnets.html)은 VPC의 IP 주소 범위입니다. 
    서브넷은 단일 가용 영역에 상주해야 합니다. 서브넷을 추가한 후에는 VPC에 AWS 리소스 배포할 수 있습니다.
    
- *IP 주소 지정*
    
    VPC와 서브넷에 [IP 주소](https://docs.aws.amazon.com/ko_kr/vpc/latest/userguide/vpc-ip-addressing.html)를 IPv4와 IPv6 모두 할당할 수 있습니다. 
    또한 퍼블릭 IPv4 주소 및 IPv6 GUA 주소를 AWS로 가져오고 VPC의 리소스에 할당할 수 있습니다.
    
- *라우팅*
    
    [라우팅 테이블](https://docs.aws.amazon.com/ko_kr/vpc/latest/userguide/VPC_Route_Tables.html)을 사용하여 서브넷 또는 게이트웨이의 네트워크 트래픽이 전달되는 위치를 결정합니다.
    
- *게이트웨이 및 엔드포인트*
    
    [게이트웨이](https://docs.aws.amazon.com/ko_kr/vpc/latest/userguide/extend-intro.html)는 VPC를 다른 네트워크에 연결합니다. 
    예를 들면, [인터넷 게이트웨이](https://docs.aws.amazon.com/ko_kr/vpc/latest/userguide/VPC_Internet_Gateway.html)를 사용하여 VPC를 인터넷에 연결합니다.
    [VPC 엔드포인트](https://docs.aws.amazon.com/vpc/latest/privatelink/privatelink-access-aws-services.html)를 사용하여 인터넷 게이트웨이 또는 NAT 장치를 사용하지 않고,
    AWS 서비스에 비공개로 연결할 수 있습니다.
    
- *피어링 연결*
    - *피어링 연결이란?*
        
        **VPC 피어링 연결은 프라이빗 IPv4 주소 또는 IPv6 주소를 사용하여 
        두 VPC 간에 트래픽을 라우팅할 수 있는 두 VPC 간의 네트워킹 연결을 의미함.**
        
    
    [VPC 피어링 연결](https://docs.aws.amazon.com/vpc/latest/peering/)을 사용하여 두 VPC의 리소스 간 트래픽을 라우팅합니다.
    
- *트래픽 미러링*
    
    네트워크 인터페이스에서 [네트워크 트래픽을 복사](https://docs.aws.amazon.com/vpc/latest/mirroring/)하고,
    심층 패킷 검사를 위해 보안 및 모니터링 어플라이언스로 전송합니다.
    
- *전송 게이트웨이*
    - *전송 게이트웨이란?*
        
        **VPC, VPN 연결 및 AWS Direct Connect 연결 간에 트래픽을 라우팅하는 중앙 허브 역할**
        
    
    중앙 허브 역할을 하는 [전송 게이트웨이](https://docs.aws.amazon.com/ko_kr/vpc/latest/userguide/extend-tgw.html)를 사용하여,
    VPC, VPN 연결 및 AWS Direct Connect 연결 간에 트래픽을 라우팅합니다.
    
- *VPC 흐름 로그*
    
    [흐름 로그](https://docs.aws.amazon.com/ko_kr/vpc/latest/userguide/flow-logs.html)는 VPC의 네트워크 인터페이스로 들어오고 나가는 IP 트래픽에 대한 정보를 캡처합니다.
    
- *VPN 연결*
    
    [AWS Virtual Private Network(AWS VPN)](https://docs.aws.amazon.com/ko_kr/vpc/latest/userguide/vpn-connections.html)을 사용하여 온프레미스 네트워크에 VPC를 연결합니다.
    

> ***Amazon VPC는 어떻게 사용할 수 있나요?***
> 
- AWS 계정에는 각 계정에는 기본 VPC가 있음.
- 기본 VPC는 EC2 인스턴스 시작 및 연결을 즉시 시작할 수 있도록 구성되어져 있음.
- 필요한 서브넷, IP 주소, 게이트웨이 및 라우팅으로 추가 VPC를 생성하도록 선택할 수 있음.
    - [VPC 생성](https://docs.aws.amazon.com/ko_kr/vpc/latest/userguide/create-vpc.html) 에 대한 추가자료.

 /Amazon VPC 작업이 가능한 인터페이스

- AWS Management Console
- AWS Command Line Interface
- AWS SDK
- 쿼리 API

### 실습 : 다이어그램 재현하기

- “VPC 마법사”로 시작하기
    1. AWS 관리 콘솔에서 **VPC 서비스**로 이동합니다.
            
    2. 왼쪽 메뉴에서 'VPC'를 선택하고, **[VPC 생성]** 버튼을 클릭합니다.
            
    3. ‘생성할 리소스'에서 [VPC 등]을 선택합니다. (이름은 'VPC and more'일 수 있습니다)
            
    4. '설정'에서 다이어그램에 맞게 다음과 같이 구성합니다.
        - **이름 태그:** `Test` (원하는 이름 입력)
        - **IPv4 CIDR 블록:** `10.0.0.0/16` (사설 IP중에서 가장 VPC에 널리 쓰이는 대역으로 설정해서 진행)
        - **가용 영역(AZ) 수:** **3개** (다이어그램과 같이 3개의 AZ를 사용)
        - **퍼블릭 서브넷 수:** **3개** (각 AZ에 하나씩 퍼블릭 서브넷 생성)
        - **프라이빗 서브넷 수:** **0개** (다이어그램에는 프라이빗 서브넷이 없습니다)
        - **NAT 게이트웨이:** **없음**
        - **VPC 엔드포인트:** **없음**
        - (외의 설정정은 기본값으로 진행했습니다.)

    5. 설정값을 확인한 후 하단의 **[VPC 생성]** 버튼을 클릭합니다.
- EC2 인스턴스 셋팅하기
    1. AWS 관리 콘솔에서 **EC2 서비스**로 이동합니다.
            
    2. **[인스턴스 시작]** 버튼을 클릭합니다.
            
    3. AMI(예: Amazon Linux 2)와 인스턴스 유형(예: t2.micro)을 선택합니다. (가장 가격이 낮은 설정, 이후에 변경할 수 있음)
            
    4. **'네트워크 설정'** 섹션에서 [편집]을 클릭합니다.
        - **VPC:** 방금 생성한 `Test-vpc`를 선택합니다.
        - **서브넷:** 3개의 퍼블릭 서브넷 중 **첫 번째 서브넷**을 선택합니다.
        - **퍼블릭 IP 자동 할당:** **활성화** 
        ('필수 설정'. 활성화해야 인스턴스가 인터넷과 통신할 수 있는 공인 IP를 받을 수 있음.)
            
    5. **'보안 그룹(방화벽)'** 설정:
        - 새 보안 그룹 생성을 선택합니다.
        - **인바운드 보안 그룹 규칙**에서 [규칙 추가]를 클릭합니다.
        - (예시) 웹 서버를 운영할 경우:
            - 유형: `HTTP`, 소스: `Anywhere` (`0.0.0.0/0`)
            - 유형: `HTTPS`, 소스: `Anywhere` (`0.0.0.0/0`)
        - (예시) 서버에 접속(관리)해야 할 경우:
            - 유형: `SSH` (Linux) 또는 `RDP` (Windows)
            - 소스: `내 IP` (보안을 위해 'Anywhere' 대신 본인의 IP 주소를 선택)
  
            
    6. 설정을 검토하고 [인스턴스 시작]을 클릭합니다.
    7. **다른 가용 영역에도 인스턴스 생성:** 위 2~6단계를 반복하되, 4단계의 **'서브넷'** 설정에서 **두 번째 서브넷**(`...-public2-...-2b`)과 **세 번째 서브넷**(`...-public3-...-2c`)을 각각 선택하여 인스턴스를 생성합니다.
    8. (이외의 설정값은 기본값으로 진행했습니다.)
- 결과
