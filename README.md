# ansible-deploy — 플레이북 책장

서버 용도별 프리셋 플레이북 모음입니다. 2번 이후는 모두 `01-base` 위에 쌓습니다.

| # | 플레이북 | 내용 | 상태 |
|---|---|---|---|
| 01 | `01-base.yaml` | 공통 설정, deploy 유저, ufw, Docker, docker rollout | ✅ |
| 02 | `02-gitea.yaml` | base + Gitea + runner + wharfline + nginx | ✅ |
| 03 | `03-gitlab.yaml` | base + GitLab CE + gitlab-runner + wharfline + nginx | ✅ |
| 04 | `04-app.yaml` | base + Traefik + 배포 디렉터리 (CI가 배포하는 대상 서버, docker rollout 무중단 배포) | ✅ |
| 05 | `05-postgres.yaml` | base + PostgreSQL | ✅ |
| 06 | `06-monitoring.yaml` | Prometheus + Grafana, 모든 서버에 node-exporter / cAdvisor | ✅ |
| 07 | `07-security.yaml` | 방화벽 규칙 재적용, fail2ban, SSH 강화, 보안 업데이트 자동 설치 (단독 실행용) | ✅ |
| 08 | `08-middleware.yaml` | RabbitMQ + Redis | ✅ |
| 09 | `09-backup.yaml` | 자동 백업 스케줄 설치(`--tags schedule`) / 즉시 백업(`--tags now`) | ✅ |
| 10 | `10-restore.yaml` | 백업 파일로 복구 | ⬜ |

## 환경
- ansible-core 2.18 이상
- 대상 서버: **Ubuntu 22.04 / 24.04** (다른 배포판은 01-base 에서 중단)
- 컬렉션: `ansible-galaxy collection install -r requirements.yaml`

## 디렉터리
```
NN-*.yaml                 # 프리셋 플레이북
roles/                    # 재사용 role
inventory/all.ini.vault   # 인벤토리 (vault 암호화)
group_vars/all/vault.yaml # 공통 변수 (vault 암호화) — 평문 예시: vault.yaml.example
```

## 실행
```bash
echo "password" > vault_password.txt

ansible-playbook -i inventory/all.ini.vault 01-base.yaml --vault-password-file vault_password.txt

# 특정 서버만 / 일부 단계만
... --limit server1
... --tags docker
```

변수 편집:
```bash
ansible-vault edit group_vars/all/vault.yaml --vault-password-file vault_password.txt
```

## 테스트
로컬 Docker에 systemd가 도는 Ubuntu 컨테이너를 띄워 실제 서버처럼 플레이북을 검증합니다.

```bash
tests/run.sh 01-base                         # 실행 → 2회차 changed=0(멱등성) → verify
tests/run.sh 01-base --keep                  # 끝나도 컨테이너 유지: docker exec -it orca-ansible-test bash
UBUNTU_VERSION=22.04 tests/run.sh 01-base    # 다른 Ubuntu 버전
```

- 점검 항목: `tests/verify/NN-*.yaml`
- 테스트 변수: `tests/vars.yaml` (vault 대신 사용, 비밀번호 불필요)
- 플레이북을 추가하면 같은 이름으로 verify 파일도 추가합니다.

## 인벤토리 그룹
각 프리셋은 같은 이름의 인벤토리 그룹에 적용됩니다 (`02-gitea.yaml` → `[gitea]`).
02 이후 플레이북은 01-base 를 먼저 실행하는데, 이때도 그 그룹에만 적용됩니다.

## 01-base 주요 변수
| 변수 | 기본값 | 설명 |
|---|---|---|
| `deploy_user` | `manager` | 생성할 배포 유저 |
| `deploy_user_ssh_keys` | `[]` | 등록할 SSH 공개키 목록 |
| `deploy_user_sudo_nopasswd` | `true` | 비밀번호 없이 sudo |
| `common_timezone` | `Asia/Seoul` | |
| `common_apt_upgrade` | `false` | 패키지 safe upgrade |
| `firewall_allowed_tcp_ports` | `[]` | 모두에게 여는 포트 (SSH는 항상 허용) |
| `firewall_rules` | `[]` | 출발지 제한 규칙 `{port, from, proto}` |
| `docker_log_max_size` / `_file` | `10m` / `3` | 컨테이너 로그 로테이션 |
| `docker_rollout_version` | `v0.14` | |

> ⚠️ Docker로 publish한 포트(`-p 5432:5432`)는 ufw를 우회해서 외부에 열립니다.
> nginx 뒤에 둘 서비스는 `127.0.0.1:포트`로만 바인딩하세요. 외부 접근 제어는 07-security에서 다룹니다.

## 02-gitea
| 구성 | 위치 | 접속 |
|---|---|---|
| nginx | 호스트 (apt) | 80 / 443 |
| Gitea + Postgres + runner | `/opt/gitea` (compose) | `http(s)://gitea_domain`, SSH `2222` |
| wharfline | `/opt/wharfline` (저장소 `deploy/` 방식) | `http(s)://wharfline_domain` |

- 필수 변수와 예시: `group_vars/all/vault.yaml.example`
- 버전: `gitea_version` 28.3.0, `gitea_runner_version` 6.0.0 ([gitea/runner](https://gitea.com/gitea/runner), Gitea 1.26.2+ 필요), `wharfline_version` v2026.11.14-1
- **HTTPS**: `nginx_certbot_email` 을 지정하면 도메인마다 Let's Encrypt 인증서를 받고 HTTP → HTTPS 로 넘깁니다. Gitea ROOT_URL 과 wharfline 쿠키 Secure 도 자동으로 https 기준이 됩니다. (DNS A 레코드가 서버를 가리켜야 함, 로컬 테스트에서는 검증하지 않음)
- **Gitea 관리자**: `gitea_admin`. `admin` 은 Gitea 예약어라 쓸 수 없습니다.
- **runner** (구 act_runner): 첫 실행 때 토큰을 발급해 자동 등록합니다. 다시 등록하려면 `/opt/gitea/runner.env` 와 `gitea_runner_data` 볼륨을 지우고 재실행하세요.
  - 기본은 upstream 권장인 DinD 이미지(`-dind`, privileged)라서 job 이 호스트 `docker.sock` 에 닿지 않습니다. job 이미지 캐시는 `gitea_runner_docker` 볼륨에 남습니다. 예전처럼 호스트 소켓을 쓰려면 `gitea_runner_docker_mode: host-socket`.
  - v6 에서 `builtin:checkout` 이 빠졌으니 workflow 에서는 `actions/checkout` 을 쓰세요. 예전 `act_runner_version` 변수는 `gitea_runner_version` 으로 바뀌었습니다.
- **wharfline 마스터 키**: `wharfline_master_key` 를 비워 두면 첫 실행 때 서버에서 만들고 `secrets/<호스트>/wharfline_master_keys` 로 가져옵니다(gitignore). **vault 로 옮기고 로컬 파일은 지우세요.** 잃으면 저장된 비밀 값을 복구할 수 없습니다.
- **wharfline 이미지는 amd64 전용**입니다. ARM 서버에서는 `wharfline_platform: linux/amd64` 로 에뮬레이션 실행할 수 있습니다(느림).

## 03-gitlab
02-gitea 의 GitLab 버전입니다. 구성은 같고 Gitea 대신 GitLab CE + gitlab-runner 가 `/opt/gitlab` 에 뜹니다.

- 버전: `gitlab_version` 19.5.5-ce.0, `gitlab_runner_version` v19.5.3
- **메모리 4GB 이상**. `gitlab_low_memory: true`(기본)는 puma 단일 프로세스, 내장 모니터링 끄기로 메모리를 아낍니다. 8GB 이상이면 false 로.
- **`gitlab_root_password` 는 무작위 문자열로** (`openssl rand -base64 18`). GitLab 은 흔한 단어 조합 비밀번호면 root 를 만들지 않고 조용히 기동합니다. role 이 이를 감지해 다시 만들고, 그래도 안 되면 이유를 보여 주고 중단합니다.
- runner: 첫 실행 때 root 의 단기 토큰(1일, create_runner 권한)으로 인스턴스 러너를 만들어 등록합니다.
- 첫 기동은 5~10분 걸립니다.

## 04-app
CI 나 wharfline 이 배포하는 **대상 서버**입니다. 앞단은 Traefik 이고, 앱은 `/srv/apps/<앱>/docker-compose.yml` 에 둡니다.

왜 nginx 가 아니라 Traefik 인가: docker rollout 은 새 컨테이너를 옆에 띄운 뒤 옛 컨테이너를 내리는데, 호스트 nginx 가 `127.0.0.1:포트` 로 프록시하면 두 컨테이너가 같은 포트를 쓸 수 없습니다. Traefik 은 컨테이너 라벨을 보고 자동으로 트래픽을 나눠서 무중단 배포가 됩니다.

앱 compose 규칙 (예시: `roles/app_host/templates/example-compose.yml.j2`)
```yaml
services:
  web:
    image: ghcr.io/me/app:1.2.3
    networks: [web]                 # container_name, ports 쓰지 않기
    labels:
      traefik.enable: "true"
      traefik.http.routers.myapp.rule: "Host(`app.example.com`)"
      traefik.http.services.myapp.loadbalancer.server.port: "8000"
    healthcheck:                    # 필수. /tmp/drain 이 있으면 unhealthy → 트래픽 빠짐
      test: ["CMD-SHELL", "test ! -f /tmp/drain && wget -qO- http://127.0.0.1:8000/health"]
      interval: 2s
      retries: 1
networks:
  web: { external: true }
```
배포: `docker compose pull web && docker rollout web --pre-stop-hook "touch /tmp/drain && sleep 5"`

- `traefik_acme_email` 을 지정하면 Let's Encrypt 자동 HTTPS
- `app_registries` 로 private 레지스트리(ghcr.io 등) 로그인
- 02/03 처럼 호스트 nginx 가 80/443 을 쓰는 서버와 같은 서버에 두지 마세요

## 05-postgres
- PostgreSQL 18 (`/opt/postgres`), 슈퍼유저 `postgres`
- `postgres_databases` 로 DB/유저 생성, 비밀번호는 실행할 때마다 vault 값으로 맞춤
- **외부 접속은 `postgres_allowed_sources` 의 CIDR 만** 허용합니다. 비우면 서버 내부에서만 접속할 수 있습니다.
- `postgres_settings` 로 `max_connections`, `shared_buffers` 등 설정

### Docker 포트 방화벽 (docker_firewall)
Docker 로 publish 한 포트는 ufw 를 거치지 않습니다. 05/08 은 `DOCKER-USER` 체인에 출발지 제한 규칙을 넣고, `docker-firewall.service` 가 Docker 재시작/재부팅 때마다 다시 적용합니다.
- 규칙 파일: `/etc/docker-firewall/rules.d/*.rules` (`<포트> <프로토콜> <허용 CIDR...>`)
- 확인: `sudo iptables -S DOCKER-USER`

## 06-monitoring
| 대상 | 구성 |
|---|---|
| `[monitoring]` | Prometheus (127.0.0.1:9090), Grafana (127.0.0.1:3001 → nginx `grafana_domain`) |
| 모든 서버 (`monitoring_targets`, 기본 all) | node-exporter :9100, cAdvisor :9280 — 모니터링 서버 IP 에서만 접근 허용 |

- Grafana 에 Prometheus 데이터소스와 **Node Exporter Full** 대시보드가 자동으로 들어갑니다 (`grafana_dashboards` 로 추가).
- 서버를 추가하면 06 을 다시 실행하세요. Prometheus 수집 대상이 인벤토리에서 다시 만들어집니다.
- 모든 컨테이너는 host 네트워크라 ufw 규칙을 그대로 따릅니다.

## 07-security
모든 서버에 적용하는 운영용 플레이북입니다. 허용 IP 를 바꿨을 때도 이것만 다시 돌리면 됩니다.

| 항목 | 내용 |
|---|---|
| 방화벽 | ufw 규칙(`firewall_*`)과 Docker 포트 규칙(05/08 의 rules.d) 재적용 |
| SSH | root 로그인 차단, `security_disable_password_auth: true` 면 비밀번호 로그인 차단, MaxAuthTries 4 등 |
| fail2ban | sshd 5회 실패 → 1시간 차단, `security_fail2ban_ignoreip` 로 관리자 IP 제외 |
| 업데이트 | unattended-upgrades 로 보안 업데이트 자동 설치 (`security_auto_reboot` 로 자동 재부팅) |

**잠김 방지**: 비밀번호 로그인을 막으려면 `deploy_user_ssh_keys` 가 있어야 하고, root 로그인을 막으려면 Ansible 이 root 가 아닌 계정으로 접속해야 합니다. 조건이 안 맞으면 실행 전에 중단합니다. 비밀번호 로그인을 막기 전에 **인벤토리를 SSH 키 접속(`ansible_user=manager`, `ansible_ssh_private_key_file=...`)으로 바꾸세요.**

## 08-middleware
- RabbitMQ 4.4 (관리 화면 포함) + Redis 8 (`/opt/middleware`)
- 5672 / 6379 는 `middleware_allowed_sources` 의 CIDR 에서만 접속 가능
- RabbitMQ 관리 화면은 127.0.0.1:15672 에만 → `ssh -L 15672:localhost:15672 manager@서버` 후 http://localhost:15672
- Redis: 비밀번호 필수, AOF 켜짐, `redis_maxmemory`(256mb) + allkeys-lru, `vm.overcommit_memory=1`
- `middleware_rabbitmq_enabled` / `middleware_redis_enabled` 로 하나만 쓸 수 있음

## 09-backup
서버에서 **실행 중인 서비스를 자동 감지**해서 백업합니다.

| 서비스 | 백업 파일 |
|---|---|
| postgres (05) | `postgres-all.sql.gz` (pg_dumpall) |
| gitea (02) | `gitea-db.dump`, `gitea-data.tar.gz` (저장소, 설정) |
| wharfline | `wharfline-db.dump` (마스터 키는 vault 에 따로) |
| gitlab (03) | `gitlab_backup.tar`, `gitlab-config.tar.gz` (gitlab-secrets.json 포함) |
| rabbitmq (08) | `rabbitmq-definitions.json` (유저, 큐, 익스체인지) |
| redis (08) | `redis-dump.rdb` |
| 공통 | `opt-configs.tar.gz` (/opt/*/docker-compose.yml, .env 등) |

```bash
ansible-playbook ... 09-backup.yaml                          # 매일 03:00 자동 백업 설치 (systemd timer)
ansible-playbook ... 09-backup.yaml --tags now               # 지금 즉시 백업
ansible-playbook ... 09-backup.yaml --tags now -e backup_fetch=true   # + backups/<호스트>/ 로 가져오기
```
- 위치: `/var/backups/orca/<시각>/` (`latest` 링크), `backup_keep_days`(7일) 지나면 삭제
- 서버에서 직접: `sudo orca-backup`, 로그: `journalctl -u orca-backup`
- **외부 저장소**: `backup_restic_repository` 를 지정하면 restic 으로 S3 / SFTP / NAS 에도 보냅니다 (일 7, 주 4, 월 6 보관). `backup_restic_password` 를 잃으면 풀 수 없습니다.
