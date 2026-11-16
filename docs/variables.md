# 변수 가이드 — 뭘 넣으면 되나

`group_vars/all/vault.yaml`(전체 서버) 또는 `host_vars/<호스트>.yaml`(한 서버만)에 적습니다.
목록/사전 변수는 **기본값에 더해지지 않고 통째로 바뀝니다** → 기본 항목도 같이 적으세요.
기본값은 `roles/<role>/defaults/main.yaml` 에 있습니다.

표기: ⭐ 추천 · ✅ 그대로 넣으면 동작 · 🔧 추가 설정 필요 · ⚠️ 주의

---

## 01 base

### `common_timezone` (기본 `Asia/Seoul`)
- 값: tz 데이터베이스 이름. `Asia/Seoul`, `UTC`, `Asia/Tokyo`, `America/Los_Angeles` …
- 전체 목록: 서버에서 `timedatectl list-timezones` · [위키 목록](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)
- ⭐ 로그 시각을 맞추려면 모든 서버를 같은 값으로.

### `common_packages`
- 01 에서 설치할 apt 패키지. 추가하려면 기본 목록 + 원하는 패키지를 모두 적기.
- 자주 추가: `tmux`, `ncdu`(디스크 사용량), `net-tools`, `dnsutils`(dig), `rsync`, `tree`
- 패키지 이름 찾기: [packages.ubuntu.com](https://packages.ubuntu.com/)

### `firewall_allowed_tcp_ports` / `firewall_rules`
```yaml
firewall_allowed_tcp_ports: [80, 443]          # 모두에게 열기
firewall_rules:                                # 출발지 제한
  - { port: 22, from: 203.0.113.0/24 }
  - { port: 51820, proto: udp, from: any }     # proto 기본 tcp
```
- `from`: 단일 IP(`203.0.113.10`), 대역(`10.0.0.0/16`), `any`
- ⚠️ Docker 로 publish 한 포트는 ufw 를 우회합니다. 06/09 는 `*_allowed_sources` 로 제한하세요.

### `docker_daemon_options`
`/etc/docker/daemon.json` 에 합쳐집니다. [전체 옵션](https://docs.docker.com/reference/cli/dockerd/#daemon-configuration-file)
```yaml
docker_daemon_options:
  live-restore: true                           # ⭐ dockerd 재시작/업그레이드 중에도 컨테이너 유지
  registry-mirrors: ["https://mirror.gcr.io"]  # Docker Hub 받기 제한 회피 (Google 미러)
  default-address-pools:                       # 사내망과 172.x 대역이 겹칠 때
    - { base: 10.200.0.0/16, size: 24 }
```

---

## 02 kubernetes
버전 변수 옆에 릴리스 링크가 있습니다 (`roles/kubernetes/defaults/main.yaml`).
- `k8s_api_allowed_sources`: kubectl 을 쓸 PC/VPN 대역. ⭐ 12-vpn 을 쓰면 `[10.13.13.0/24]`
- `k8s_api_cert_sans`: 원격에서 접속할 주소. `[k8s.example.com, 203.0.113.5]`
- `k8s_pod_subnet` ⚠️ 사내망/VPC 와 겹치지 않게. 바꾸면 클러스터 재생성 필요.

---

## 03 gitea

### `gitea_runner_labels` (기본: act_runner 기본 라벨)
- 형식: `라벨:docker://이미지`, 여러 개는 쉼표로. 워크플로의 `runs-on:` 이 라벨과 일치해야 실행됨.
```yaml
gitea_runner_labels: "ubuntu-latest:docker://node:22-bookworm,ubuntu-24.04:docker://ubuntu:24.04"
```
- ⭐ GitHub Actions 와 비슷한 환경: `docker.gitea.com/runner-images:ubuntu-latest` (기본값)
- [act_runner 라벨 문서](https://docs.gitea.com/usage/actions/act-runner#labels)

### `gitea_ssh_port` (기본 2222)
- 22 는 서버 SSH 가 씀. 클론 주소: `ssh://git@git.example.com:2222/owner/repo.git`

---

## 04 gitlab

### `gitlab_low_memory`
| 서버 메모리 | 값 |
|---|---|
| 4GB | `true` (기본) — puma 1개, 내장 모니터링 끔 |
| 8GB 이상 | `false` ⭐ |
[GitLab 요구 사양](https://docs.gitlab.com/install/requirements/)

### `gitlab_runner_docker_image` (기본 `alpine:latest`)
`.gitlab-ci.yml` 에 `image:` 가 없을 때 쓰는 이미지.
- `alpine:latest` (가벼움) · `ubuntu:24.04` (apt 필요할 때) · `node:22`, `python:3.13` (언어별)
- 러너는 호스트 docker.sock 을 씁니다 → job 에서 `docker build` 가능 (dind 불필요). ⚠️ job 이 호스트 Docker 를 다룰 수 있으니 신뢰하는 저장소만.

---

## 05 app

### `app_registries`
```yaml
app_registries:
  - { registry: ghcr.io, username: <깃허브ID>, password: "<토큰>" }
  - { registry: https://index.docker.io/v1/, username: <도커허브ID>, password: "<토큰>" }
  - { registry: registry.gitlab.com, username: <배포토큰 이름>, password: "<토큰>" }
  - { registry: git.example.com, username: <gitea 유저>, password: "<토큰>" }   # 03 의 Gitea 패키지
```
| 레지스트리 | 토큰 만드는 곳 / 권한 |
|---|---|
| GitHub (ghcr.io) | Settings → Developer settings → PAT(classic), `read:packages` · [문서](https://docs.github.com/packages/working-with-a-github-packages-registry/working-with-the-container-registry) |
| Docker Hub | Account settings → Personal access tokens, Read-only · [문서](https://docs.docker.com/security/access-tokens/) |
| GitLab | 프로젝트 → Settings → Repository → Deploy tokens, `read_registry` · [문서](https://docs.gitlab.com/user/project/deploy_tokens/) |
| Gitea | 설정 → 애플리케이션 → 토큰, `read:package` · [문서](https://docs.gitea.com/usage/packages/container) |

---

## 06 postgres

### `postgres_allowed_sources`
- 비우면 서버 내부(같은 서버의 컨테이너)에서만. 예) 같은 VPC `[10.0.0.0/16]`, 앱 서버 하나 `[10.0.1.5/32]`, VPN `[10.13.13.0/24]`
- ⚠️ `0.0.0.0/0` 은 인터넷 전체 공개. 쓰지 마세요.

### `postgres_settings` (통째로 바뀜)
- 계산기: ⭐ [PGTune](https://pgtune.leopard.in.ua/) — 버전 18, 메모리, CPU, 용도(Web) 입력 후 결과를 옮기기
- 대략: `shared_buffers` = 메모리 25%, `effective_cache_size` = 메모리 70%
```yaml
postgres_settings:          # 4GB / 2CPU / 웹 앱 예시
  max_connections: 200
  shared_buffers: 1GB
  effective_cache_size: 3GB
  maintenance_work_mem: 256MB
  work_mem: 5MB
  log_min_duration_statement: 1000
```
- [설정 문서](https://www.postgresql.org/docs/current/runtime-config.html)

---

## 07 monitoring

### `grafana_dashboards` (grafana.com 대시보드 ID)
| ID | 이름 | 상태 |
|---|---|---|
| 1860 | Node Exporter Full (서버 CPU/메모리/디스크) | ✅ 기본, 테스트됨 |
| 14282 | Cadvisor exporter (컨테이너별 사용량) | ✅ ⭐ |
| 893 | Docker and system monitoring | ✅ |
| 9628 | PostgreSQL Database | 🔧 postgres_exporter 가 없어 빈 화면 |
| 3662 | Prometheus 2.0 Overview | ⚠️ 데이터소스 변수 이름이 달라 연결 안 됨 |
```yaml
grafana_dashboards:
  - { id: 1860, name: node-exporter-full }
  - { id: 14282, name: cadvisor }
```
- 찾기: [grafana.com/grafana/dashboards](https://grafana.com/grafana/dashboards/) (Data source: Prometheus 로 필터). 받은 JSON 의 `${DS_PROMETHEUS}` 만 자동으로 바꿔 줍니다.

### 알림 채널
| 채널 | 넣을 값 | 얻는 법 |
|---|---|---|
| Slack | `alert_slack_webhook_url`, `alert_slack_channel` | [Incoming Webhooks](https://api.slack.com/messaging/webhooks) 앱 추가 → URL 복사 |
| Telegram | `alert_telegram_bot_token`, `alert_telegram_chat_id` | ① [@BotFather](https://t.me/BotFather) 에서 `/newbot` → 토큰 ② 봇에게 메시지 보내기(그룹이면 봇 초대) ③ `https://api.telegram.org/bot<토큰>/getUpdates` 의 `chat.id` (그룹은 음수) |
| 웹훅 | `alert_webhook_url` | 받는 쪽이 [Alertmanager 웹훅 형식](https://prometheus.io/docs/alerting/latest/configuration/#webhook_config) JSON 을 처리해야 함 |

Discord / MS Teams 는 Alertmanager 가 지원하지만 이 템플릿에는 아직 없습니다.

### 그 밖
- `prometheus_retention`: `15d`(기본), `30d`, `12w`, `1y`. 단위 `h d w y`. 대략 서버 1대·30초 간격에 하루 수 MB.
- `prometheus_scrape_interval`: `15s`~`60s`. 짧을수록 정밀하고 디스크를 더 씀. ⭐ `30s`
- 경보 기준: `alert_disk_free_percent`(15), `alert_memory_used_percent`(90), `alert_load_per_core`(2)

---

## 08 security / CrowdSec

### `security_whitelist_ips`
- 절대 차단하면 안 되는 관리자 IP. 집/회사 공인 IP 는 [ifconfig.me](https://ifconfig.me) 로 확인. 예) `[203.0.113.10, 198.51.100.0/24]`
- [vpn] 서버는 VPN 대역이 자동으로 들어갑니다.

### `crowdsec_collections` (통째로 바뀜)
탐지 규칙 묶음. 이름은 [CrowdSec Hub](https://app.crowdsec.net/hub/collections) 에서 찾습니다.

| 컬렉션 | 하는 일 | 상태 |
|---|---|---|
| `crowdsecurity/linux` | syslog 파서 + GeoIP | ✅ 기본 |
| `crowdsecurity/sshd` | SSH 무차별 대입 | ✅ 기본 |
| `crowdsecurity/traefik` | Traefik 액세스 로그 + 일반 HTTP 시나리오 | ✅ 기본 |
| `crowdsecurity/http-cve` | 알려진 웹 취약점 공격 | ✅ 기본 |
| `crowdsecurity/base-http-scenarios` | 스캐너, 민감 파일 탐색 | ✅ 기본 |
| `crowdsecurity/whitelist-good-actors` | 검색엔진·CDN 등 정상 봇은 차단 안 함 | ✅ ⭐ 공개 웹서비스면 추가 |
| `crowdsecurity/iptables` | 포트 스캔 탐지 (ufw 차단 로그) | 🔧 `crowdsec_acquisitions` 에 kern.log 추가 (아래) |
| `crowdsecurity/http-dos` | HTTP 과다 요청 | ✅ (오탐 확인 후 사용) |
| `LePresidente/gitea` | Gitea 로그인 무차별 대입 | 🔧 컨테이너 로그 수집이 필요 — 이 role 은 파일 로그만 읽음 |
| `timokoessler/gitlab` | GitLab 로그인 무차별 대입 | 🔧 위와 같음 |
| `LePresidente/grafana` | Grafana 로그인 무차별 대입 | 🔧 위와 같음 |
| `crowdsecurity/wireguard` | WireGuard | ⚠️ 쓰지 않음 (README 12-vpn 참고) |

추천 조합 (공개 웹서비스 서버):
```yaml
crowdsec_collections:
  - crowdsecurity/linux
  - crowdsecurity/sshd
  - crowdsecurity/traefik
  - crowdsecurity/http-cve
  - crowdsecurity/base-http-scenarios
  - crowdsecurity/whitelist-good-actors
  - crowdsecurity/iptables
crowdsec_acquisitions:
  - { path: /var/log/host/auth.log, type: syslog }
  - { path: /var/log/host/traefik/access.log, type: traefik }
  - { path: /var/log/host/kern.log, type: syslog }      # iptables 용
```
- 위 조합 중 기본 5개만 테스트에서 동작을 확인했습니다. 추가 항목은 적용 후 `cscli metrics` 로 확인하세요.
- ⚠️ 목록에서 빼도 이미 설치된 컬렉션은 남습니다. 지우려면 `docker exec crowdsec cscli collections remove <이름>`
- 확인: `docker exec crowdsec cscli collections list` · `cscli metrics` (로그를 실제로 읽는지)

### `crowdsec_acquisitions`
- `path`: 호스트 `/var/log` 는 컨테이너에서 `/var/log/host` 입니다.
- `type`: 로그를 해석할 파서 종류. `syslog`(auth.log, kern.log, syslog), `traefik`, `nginx` … 컬렉션 페이지의 "Acquisition" 항목에 적혀 있음.

### `crowdsec_enroll_key`
- [app.crowdsec.net](https://app.crowdsec.net) 가입 → Security Engines → Enroll 에서 복사. 웹에서 차단 현황을 봄. 선택 사항.

### SSH
- `security_ssh_allow_users`: SSH 로그인 허용 유저. ⭐ `[manager]` (deploy_user). ⚠️ 지금 접속하는 유저를 빼면 잠김.
- `security_disable_password_auth: true` ⭐ 키 접속이 확인된 뒤에.
- `security_auto_reboot_time`: `"HH:MM"` 24시간제, 서버 시간대 기준.

---

## 09 middleware

### `redis_maxmemory_policy` (기본 `allkeys-lru`)
| 값 | 메모리가 차면 | 용도 |
|---|---|---|
| `allkeys-lru` ⭐ | 오래 안 쓴 키부터 삭제 | 캐시 |
| `allkeys-lfu` | 덜 쓰는 키부터 삭제 | 캐시 (인기 키가 뚜렷할 때) |
| `volatile-lru` | 만료시간(TTL) 있는 키만 삭제 | 캐시 + 영구 데이터 혼용 |
| `volatile-ttl` | 만료가 가까운 키부터 | |
| `noeviction` | 쓰기 거부(에러) | 큐, 세션 등 잃으면 안 될 때 |

[Redis eviction 문서](https://redis.io/docs/latest/develop/reference/eviction/)
- `redis_maxmemory`: `256mb`, `1gb` … 서버 메모리의 절반 이하 권장.

### `middleware_allowed_sources`
06 의 `postgres_allowed_sources` 와 같은 형식.

---

## 10 backup / 11 restore

### `backup_schedule` (systemd OnCalendar)
| 값 | 의미 |
|---|---|
| `*-*-* 03:00:00` | 매일 03시 (기본) |
| `*-*-* 00/6:00:00` | 6시간마다 |
| `Mon *-*-* 04:00:00` | 매주 월요일 04시 |
| `hourly` / `daily` / `weekly` | 정각 / 자정 / 월요일 자정 |
- 확인: `systemd-analyze calendar "*-*-* 00/6:00:00"` · [문법](https://www.freedesktop.org/software/systemd/man/latest/systemd.time.html#Calendar%20Events)

### `backup_restic_repository` + `backup_restic_env`
| 저장소 | repository | env |
|---|---|---|
| 서버 안 다른 디스크 | `/mnt/backup/orca` | 없음 |
| NCP Object Storage | `s3:https://kr.object.ncloudstorage.com/<버킷>/orca` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` |
| AWS S3 (서울) | `s3:s3.ap-northeast-2.amazonaws.com/<버킷>/orca` | 위와 같음 |
| Cloudflare R2 | `s3:https://<계정ID>.r2.cloudflarestorage.com/<버킷>/orca` | 위와 같음 (R2 API 토큰) |
| Backblaze B2 | `b2:<버킷>:orca` | `B2_ACCOUNT_ID`, `B2_ACCOUNT_KEY` |
| restic REST 서버 | `rest:https://user:pass@backup.example.com/orca` | 없음 |
- ⚠️ `sftp:` 은 지금 쓸 수 없습니다 (restic 이 컨테이너로 돌아서 SSH 키가 없음).
- ⭐ 서버와 다른 곳(다른 클라우드/리전)에 두기. `backup_restic_password` 는 vault 와 별도로 한 번 더 보관.
- [저장소 종류 문서](https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html)

### `backup_restic_forget` (기본 `--keep-daily 7 --keep-weekly 4 --keep-monthly 6`)
- 옵션: `--keep-last N`, `--keep-hourly N`, `--keep-daily N`, `--keep-weekly N`, `--keep-monthly N`, `--keep-yearly N`, `--keep-within 30d`
- [forget 문서](https://restic.readthedocs.io/en/stable/060_forget.html)

### 11 restore (실행할 때 `-e` 로)
- `restore_components`: `postgres gitea wharfline gitlab rabbitmq redis` 중 고르기. 예) `-e '{"restore_components":["postgres"]}'`
- `restore_from`: `latest`(기본) 또는 백업 폴더 이름 `20261115-030000` (`ls /var/backups/orca`)
- `restore_restic_snapshot`: `latest` 또는 스냅샷 ID (`sudo orca-restic snapshots`)
- `restore_confirm: "yes"` 필수

---

## 12 vpn

- `vpn_server_url`: `auto`(공인 IP 자동) 또는 도메인 `vpn.example.com`. ⭐ IP 가 바뀔 수 있으면 도메인.
- `vpn_peers`: 기기 이름 목록. 영문·숫자만. `[laptop, phone, ipad]`. 한 기기에 한 이름 (같은 설정을 두 기기에서 쓰면 서로 끊김).
- `vpn_subnet`: `10.13.13.0` 형식(/24 고정). ⚠️ 집/회사 공유기 대역(`192.168.0.x`, `192.168.1.x`)과 겹치지 않게.
- `vpn_allowed_ips`: 클라이언트가 VPN 으로 보낼 대역
  - `10.13.13.0/24` ⭐ 기본: VPN 안의 서버만 (나머지 인터넷은 그대로)
  - `10.13.13.0/24,10.0.0.0/16`: VPN + 서버가 속한 VPC
  - `0.0.0.0/0`: 모든 트래픽 (카페 와이파이 보호용)
- `vpn_peer_dns`: `auto`(서버 컨테이너의 DNS) 또는 `1.1.1.1`, `8.8.8.8`
- 클라이언트 앱: [WireGuard 설치](https://www.wireguard.com/install/) → `secrets/<호스트>/wireguard/<이름>.conf` 가져오기. 휴대폰은 서버에서 `docker exec wireguard /app/show-peer phone` 으로 QR 표시

---

## 13 user (실행할 때 입력, 또는 `-e` 로)

- `account_name`: 영문 소문자로 시작하는 소문자·숫자·`_`·`-` (32자 이하). `root` 와 `deploy_user` 는 안 됨. ⭐ 사람 이름 그대로 `alice`, `jdoe`.
- `account_password`: 8자 이상. ⭐ 입력 받기 (`-e` 는 셸 기록에 남음). 처음 들어간 뒤 `passwd` 로 본인이 바꾸게 해도 됩니다.
- `account_sudo`: `yes` / `no` (기본 `no`). ⭐ 서버를 직접 관리하는 사람만 `yes`.
- `account_ssh_keys`: 선택. 공개키 목록. ⭐ 08 에서 비밀번호 로그인을 막을 거면 필수. 키 만들기: `ssh-keygen -t ed25519`
- `account_shell`: 기본 `/bin/bash`.

---

## 버전 올리기
각 role defaults 의 `*_version` 옆에 릴리스 링크가 있습니다. 올린 뒤 `tests/run.sh NN-xxx.yaml` 로 확인하세요.
