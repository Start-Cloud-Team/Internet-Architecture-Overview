- nvicti
검증된 취약점 탐지 성능과 AI 기능을 결합한 도구로 (기업 한정)현재 무료 체험 가능

- HCL AppScan
클라우드, 온프레미스 등 다양한 환경 지원, 자동화와 통합에 강점
30일 동안 5회 무료 실행 가능

- Tenable Nessus
광범위한 취약점 탐지, 빠른 스캔, 낮은 오탐률, 자동화, 플러그인 업데이트 등을 갖춘 취약점 진단



---
- Nikto
웹 서버 취약점 진단에 특화된 오픈소스 스캐너로, 다양한 플러그인을 통해 오래된 서버 버전, 잘못된 설정, 잠재적 보안 문제 등을 빠르게 탐지

cli로 실습 진행해보았습니다.

- 설치

```python
sudo apt update
suto apt install nikto
```

- 실행 명령어

```python
nikto -h http://bwapp-alb-880850831.ap-northeast-2.elb.amazonaws.com/WebGoat/login
```

- 결과
```python
- Nikto v2.1.5
---------------------------------------------------------------------------
+ Target IP:          52.79.204.217
+ Target Hostname:    bwapp-alb-880850831.ap-northeast-2.elb.amazonaws.com
+ Target Port:        80
+ Start Time:         2025-11-30 18:26:38 (GMT9)
---------------------------------------------------------------------------
+ Server: No banner retrieved
+ The anti-clickjacking X-Frame-Options header is not present.
+ No CGI Directories found (use '-C all' to force check all possible dirs)
+ Server banner has changed from '' to 'awselb/2.0' which may suggest a WAF, load balancer or proxy is in place
+ OSVDB-3931: /myphpnuke/links.php?op=MostPopular&ratenum=[script]alert(document.cookie);[/script]&ratetype=percent: myphpnuke is vulnerable to Cross Site Scripting (XSS). http://www.cert.org/advisories/CA-2000-02.html.
+ OSVDB-4598: /members.asp?SF=%22;}alert(223344);function%20x(){v%20=%22: Web Wiz Forums ver. 7.01 and below is vulnerable to Cross Site Scripting (XSS). http://www.cert.org/advisories/CA-2000-02.html.
+ OSVDB-2946: /forum_members.asp?find=%22;}alert(9823);function%20x(){v%20=%22: Web Wiz Forums ver. 7.01 and below is vulnerable to Cross Site Scripting (XSS). http://www.cert.org/advisories/CA-2000-02.html.
+ 6544 items checked: 0 error(s) and 4 item(s) reported on remote host
+ End Time:           2025-11-30 18:32:13 (GMT9) (335 seconds)
---------------------------------------------------------------------------
+ 1 host(s) tested
```

---
## Sparrow dast

국산 솔루션으로 정부 및 국내 컴플라이언스 기준 충족, 다양한 정책 보고서와 레퍼런스 지원.

---

<img width="1395" height="747" alt="image" src="https://github.com/user-attachments/assets/429c3af7-df4a-46ea-b0da-6e44badf167a" />
<img width="2877" height="1282" alt="image" src="https://github.com/user-attachments/assets/6d6f13a7-d5fc-4cf0-a01a-3f8c02b80c52" />
<img width="2879" height="1278" alt="image" src="https://github.com/user-attachments/assets/ecfd867f-8bd0-42c8-9ed0-531b98e7d852" />
<img width="1185" height="1258" alt="image" src="https://github.com/user-attachments/assets/adb78798-46a1-4a04-848f-36fdee948fd2" />
<img width="1186" height="1241" alt="image" src="https://github.com/user-attachments/assets/fd199d1a-46f1-4533-9b7f-cc347161c368" />
<img width="1186" height="1240" alt="image" src="https://github.com/user-attachments/assets/4770340e-48f1-4b48-803d-77756684b2a9" />
이후 더 진행 하려고 했지만 `이후 진행 방법을 찾지 못해`진행하지 못했습니다..
