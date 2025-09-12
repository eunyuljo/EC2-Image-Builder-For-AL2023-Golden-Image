# ISMS 준수 Golden AMI - EC2 Image Builder

이 프로젝트는 ISMS(정보보호 관리체계) 심사 기준에 맞는 Golden AMI를 AWS EC2 Image Builder를 사용하여 자동으로 생성하는 솔루션입니다.

## 📋 주요 특징

### ISMS 보안 요구사항 준수
- **시스템 보안 강화**: 불필요한 서비스 비활성화, 커널 매개변수 보안 설정
- **접근 통제**: SSH 보안 강화, 패스워드 정책 적용
- **로깅 및 모니터링**: CloudWatch Agent 통합, 보안 로그 수집
- **파일 무결성 모니터링**: AIDE 설치 및 구성
- **암호화**: EBS 볼륨 암호화, S3 버킷 암호화
- **네트워크 보안**: 최소 권한 보안 그룹, 프라이빗 서브넷 사용

### 자동화 기능
- **주간 자동 빌드**: 매주 일요일 새벽 2시 자동 실행
- **보안 업데이트**: 최신 보안 패치 자동 적용
- **무결성 검증**: 이미지 테스트 자동 실행
- **태깅 정책**: 규정 준수를 위한 자동 태깅

## 🏗️ 아키텍처

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Image Recipe  │────│ Infrastructure   │────│  Distribution   │
│                 │    │  Configuration   │    │  Configuration  │
│ • Base AMI      │    │                  │    │                 │
│ • Components    │    │ • Instance Type  │    │ • Target Region │
│ • Block Device  │    │ • Security Group │    │ • AMI Tags      │
└─────────────────┘    │ • Subnet         │    │ • Sharing       │
                       │ • IAM Profile    │    └─────────────────┘
                       └──────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │  Image Pipeline  │
                       │                  │
                       │ • Schedule       │
                       │ • Status         │
                       │ • Execution      │
                       └──────────────────┘
```

## 📦 구성 요소

### 1. 보안 강화 컴포넌트 (`isms_security_hardening`)
- 시스템 업데이트 및 보안 패치 적용
- 불필요한 서비스 및 패키지 제거
- SSH 보안 설정 강화
- 커널 매개변수 보안 구성
- 파일 권한 및 접근 제어 설정
- 계정 보안 정책 적용
- 파일 무결성 모니터링(AIDE) 구성
- 로그 설정 및 보안 배너 구성

### 2. 모니터링 컴포넌트 (`cloudwatch_agent_config`)
- CloudWatch Agent 설치 및 구성
- 시스템 메트릭 수집 (CPU, 메모리, 디스크, 네트워크)
- 보안 로그 수집 (시스템, 인증, 보안 로그)
- 실시간 모니터링 대시보드 연동

### 3. Infrastructure Configuration
- EC2 인스턴스 프로필 및 IAM 역할
- 보안 그룹 (최소 권한 원칙)
- 프라이빗 서브넷에서 빌드 실행
- EBS 볼륨 암호화
- 로그 수집을 위한 S3 버킷

## 🚀 설치 및 배포

### 사전 요구사항
- AWS CLI 설치 및 구성
- Terraform >= 1.0
- 적절한 AWS 권한 (EC2, IAM, S3, ImageBuilder)

### 1. 저장소 클론 및 설정
```bash
# 프로젝트 디렉토리로 이동
cd ec2-image-builder

# Terraform 변수 파일 설정
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# terraform.tfvars 파일 편집 (VPC ID, Subnet ID 등 설정)
vim terraform/terraform.tfvars
```

### 2. 필수 설정 항목
`terraform/terraform.tfvars` 파일에서 다음 항목들을 실제 값으로 업데이트하세요:

```hcl
# AWS 설정
aws_region = "ap-northeast-2"

# 프로젝트 설정
project_name = "isms-golden-ami"
environment  = "prod"

# 네트워크 설정
vpc_id    = "vpc-xxxxxxxxx"        # 실제 VPC ID
subnet_id = "subnet-xxxxxxxxx"     # 실제 프라이빗 서브넷 ID

# 암호화 (선택사항)
kms_key_id = "arn:aws:kms:ap-northeast-2:123456789012:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# 빌드 인스턴스 타입
instance_types = ["t3.medium", "t3.large"]

# AMI 공유 대상 (선택사항)
allowed_principals = ["123456789012"]
```

### 3. 인프라 배포
```bash
# 스크립트에 실행 권한 부여
chmod +x scripts/*.sh

# 인프라 배포 실행
./scripts/deploy.sh
```

### 4. 이미지 빌드 시작 (선택사항)
배포 시 자동으로 묻거나, 나중에 수동으로 실행:
```bash
./scripts/start-pipeline.sh
```

### 5. 빌드 모니터링
```bash
# 현재 상태 확인
./scripts/monitor-pipeline.sh

# 실시간 모니터링
./scripts/monitor-pipeline.sh --watch
```

## 📊 모니터링 및 운영

### 빌드 상태 확인
- `BUILDING`: 이미지 빌드 진행 중
- `TESTING`: 이미지 테스트 진행 중  
- `DISTRIBUTING`: AMI 생성 및 배포 중
- `AVAILABLE`: 빌드 완료, AMI 사용 가능
- `FAILED`: 빌드 실패

### 로그 확인
- **빌드 로그**: S3 버킷 (`{project_name}-image-builder-logs-{account_id}-{region}`)
- **CloudWatch 로그**: 
  - `ISMS-GoldenAMI-SystemLogs`
  - `ISMS-GoldenAMI-SecurityLogs`
  - `ISMS-GoldenAMI-AuthLogs`

### 스크립트 구조
- **ISMS 보안 강화**: `scripts/isms-security-hardening.sh`
- **CloudWatch 설정**: `scripts/cloudwatch-agent-config.sh`
- 스크립트는 별도 파일로 분리되어 관리가 용이함

## 🔒 보안 기능

### 1. 시스템 보안 강화
- 최신 보안 패치 적용
- 불필요한 서비스 비활성화 (cups, bluetooth 등)
- 텔넷, rsh 등 불안전한 프로토콜 제거

### 2. SSH 보안 설정
- 패스워드 인증 비활성화
- Root 로그인 비활성화  
- 최대 인증 시도 제한 (3회)
- 클라이언트 연결 타임아웃 설정

### 3. 네트워크 보안
- IP 포워딩 비활성화
- ICMP 리다이렉트 비활성화
- SYN 쿠키 활성화
- 마틴 패킷 로깅 활성화

### 4. 접근 제어
- 파일 권한 강화 (/root 700, /etc/shadow 000 등)
- 패스워드 정책 적용 (최대 90일, 최소 7일 등)
- 사용자 계정 보안 설정

### 5. 모니터링 및 로깅
- 파일 무결성 모니터링 (AIDE)
- 보안 이벤트 로깅
- CloudWatch 통합 모니터링
- 실패한 로그인 추적

### 6. 규정 준수
- ISMS-P 관련 태그 자동 적용
- 시간 동기화 (NTP)
- 보안 배너 설정
- 암호화 정책 적용

## 🏷️ 태그 정책

생성되는 모든 리소스와 AMI에는 다음 태그가 자동으로 적용됩니다:

```
Name: {project_name}-golden-ami
Environment: {environment}
BuildDate: YYYY-MM-DD
Purpose: ISMS-Compliant-Golden-AMI
Compliance: ISMS-K-21.1
BaseImage: Amazon Linux 2
Hardened: true
```

## 🔧 사용자 정의

### 추가 보안 컴포넌트 작성
`terraform/image-builder.tf`에서 새로운 컴포넌트를 추가할 수 있습니다:

```hcl
resource "aws_imagebuilder_component" "custom_component" {
  name     = "${var.project_name}-custom-component"
  platform = "Linux"
  version  = "1.0.0"
  
  data = yamlencode({
    # 컴포넌트 정의
  })
}
```

### 빌드 스케줄 변경
파이프라인의 스케줄을 변경하려면:

```hcl
schedule {
  schedule_expression = "cron(0 2 * * sun)"  # 매주 일요일 2 AM
  pipeline_execution_start_condition = "EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE"
}
```

## 📝 참고사항

### 비용 최적화
- 빌드는 프라이빗 서브넷에서 실행되어 NAT Gateway 비용 발생
- 인스턴스 타입을 t3.medium 이상 권장 (빌드 성능)
- 불필요한 빌드 실행을 방지하기 위해 종속성 변경 시에만 실행

### 트러블슈팅
- **빌드 실패**: S3 로그 버킷에서 상세 로그 확인
- **네트워크 오류**: 프라이빗 서브넷의 NAT Gateway 연결 확인
- **권한 오류**: IAM 역할 및 정책 확인

### 업그레이드
- 컴포넌트 버전 업데이트 시 버전 번호 증가 필요
- Terraform 상태 파일 백업 권장
- 변경사항 적용 전 테스트 환경에서 검증

## 📞 지원

문제가 발생하거나 개선사항이 있다면 이슈를 생성해주세요.

---

**주의**: 이 솔루션은 ISMS 요구사항을 기반으로 설계되었지만, 조직의 특정 보안 정책과 요구사항에 따라 추가 구성이 필요할 수 있습니다.