# ansible-deploy — 플레이북 책장

서버 용도별 프리셋 플레이북 모음입니다. 2번 이후는 모두 `01-base` 위에 쌓습니다.

| # | 플레이북 | 내용 | 상태 |
|---|---|---|---|
| 01 | `01-base.yaml` | 공통 설정, deploy 유저, ufw, Docker, docker rollout | ✅ |
| 02 | `02-kubernetes.yaml` | base(Docker) + Kubernetes 단일 노드 (kubeadm, Flannel, Helm, metrics-server, local-path, Traefik ingress, etcd 백업) | ✅ |
| 03 | `03-gitea.yaml` | base + Traefik + Gitea + act_runner + wharfline | ✅ |
| 04 | `04-gitlab.yaml` | base + Traefik + GitLab CE + gitlab-runner + wharfline | ✅ |
| 05 | `05-app.yaml` | base + Traefik + 배포 디렉터리 (CI가 배포하는 대상 서버, docker rollout 무중단 배포) | ✅ |
| 06 | `06-postgres.yaml` | base + PostgreSQL | ✅ |
| 07 | `07-monitoring.yaml` | Prometheus + Grafana + Alertmanager, 모든 서버에 node-exporter / cAdvisor | ✅ |
| 08 | `08-security.yaml` | 방화벽 규칙 재적용, CrowdSec, SSH 강화, 보안 업데이트 자동 설치 (단독 실행용) | ✅ |
| 09 | `09-middleware.yaml` | RabbitMQ + Redis | ✅ |
| 10 | `10-backup.yaml` | 자동 백업 스케줄 설치(`--tags schedule`) / 즉시 백업(`--tags now`) | ✅ |
| 11 | `11-restore.yaml` | 백업 파일로 복구 | ✅ |
| 12 | `12-vpn.yaml` | base + WireGuard VPN (관리자 내부망 접속, 접속 설정 자동 생성) | ✅ |

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
docs/variables.md         # 변수별 넣을 값 / 추천 / 참고 링크
```

## 실행
```bash
echo "password" > vault_password.txt

ansible-playbook -i inventory/all.ini.vault 01-base.yaml --vault-password-file vault_password.txt

# 특정 서버만 / 일부 단계만
... --limit server1
... --tags docker
```

변수 편집 (뭘 넣을지는 [docs/variables.md](docs/variables.md) — 값 목록, 추천, 참고 링크):
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
- 사전 준비: `tests/prepare/NN-*.yaml` 이 있으면 먼저 실행 (08 은 base, 10/11 은 서비스+표시 데이터)
- 테스트 이미지는 속도를 위해 KAIST apt 미러를 씁니다 (`APT_MIRROR=` 로 기본 미러)
- 플레이북을 추가하면 같은 이름으로 verify 파일도 추가합니다.
- 소요 시간(대략): 01 2분, 03 6분, 04 20분(GitLab), 05~10 3~5분, 11 10분
- wharfline 이미지는 amd64 전용이라 arm64 Mac 에서는 에뮬레이션으로 돕니다 (`tests/vars.yaml` 의 `wharfline_platform`)

## 인벤토리 그룹
각 프리셋은 같은 이름의 인벤토리 그룹에 적용됩니다 (`03-gitea.yaml` → `[gitea]`).
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
> Traefik 뒤에 둘 서비스는 포트를 publish 하지 말고 `web` 네트워크 + 라벨로 연결하세요. 외부 접근 제어는 07-security에서 다룹니다.

## 02-kubernetes
Docker(01-base) 위에 **kubeadm 으로 단일 노드 Kubernetes** 를 설치합니다. Docker 와 Kubernetes 가 같은 containerd 를 나눠 써서(Docker: `moby` / k8s: `k8s.io` 네임스페이스) docker compose 서비스와 kubectl/helm 을 한 서버에서 같이 쓸 수 있습니다.

| 구성 | 버전 변수 (기본값) | 설명 |
|---|---|---|
| kubeadm / kubelet / kubectl | `k8s_version` 1.37.2 | apt hold 로 고정, 버전을 바꾸면 hold 를 풀고 설치 |
| containerd (CRI) | Docker 의 containerd.io | CRI 켜기 + `SystemdCgroup = true` |
| Flannel (CNI) | `k8s_flannel_version` v0.28.10 | Pod 대역 `k8s_pod_subnet` 10.244.0.0/16 |
| Helm | `k8s_helm_version` v4.3.2 | `/usr/local/bin/helm` |
| metrics-server | `k8s_metrics_server_version` v0.9.1 | `kubectl top`, HPA |
| local-path-provisioner | `k8s_local_path_version` v0.0.37 | 기본 StorageClass, 데이터는 `k8s_local_path_dir` |
| Traefik (ingress) | `k8s_traefik_chart_version` 42.4.0 | 기본 IngressClass, hostPort 로 노드 80/443 수신 |
| etcd 스냅샷 | — | 매일 03:30 `/var/backups/etcd` (7개 보관, PKI 포함) |

- 인벤토리 `[kubernetes]` 그룹에 적용. control-plane 에도 일반 Pod 가 뜹니다(`k8s_control_plane_schedulable`).
- 서버에서: `kubectl get pods -A` (deploy 유저도 `~/.kube/config` 로 바로 사용, `k` 별칭 + 자동완성)
- **원격 kubectl**: `k8s_api_allowed_sources` 에 내 IP 대역, `k8s_api_cert_sans` 에 접속할 도메인/IP 를 넣고 실행 → 서버의 `~/.kube/config` 를 가져와 `server:` 주소만 바꿔 쓰세요. 기본은 6443 을 열지 않습니다.
- **ingress 예시**: `Ingress` 를 만들고 도메인 DNS 를 서버로 향하게 하면 Traefik 이 80/443 에서 받습니다. ⚠️ hostPort 80/443 을 쓰므로 03 · 04 · 05 · 07(Traefik 80/443) 과 같은 서버에 두지 마세요 (`k8s_ingress_enabled: false` 로 끌 수 있음).
- 방화벽: Pod 대역(10.244.0.0/16) → 노드 허용, ingress 켜면 80/443 허용.
- 애드온 매니페스트는 `/etc/kubernetes/addons/<이름>/` (kustomization) 에 남고, `kubectl diff` 로 바뀐 게 있을 때만 적용합니다.
- etcd 수동 백업: `sudo k8s-etcd-backup`, 복구는 [공식 문서](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#restoring-an-etcd-cluster) 참고.
- 테스트(컨테이너)에서는 swap 유지, 커널 모듈 로드 생략, `kube-proxy conntrack.maxPerCore: 0` 을 씁니다 (`tests/vars.yaml`). 실서버에서는 swap 을 끄고 모듈을 로드합니다.
- 미지원: 멀티 노드(worker join), HA control-plane.

## 03-gitea
| 구성 | 위치 | 접속 |
|---|---|---|
| Traefik | `/opt/traefik` (컨테이너, 03/04/05/07 공용) | 80 / 443 |
| Gitea + Postgres + act_runner | `/opt/gitea` (compose) | `http(s)://gitea_domain`, SSH `2222` |
| wharfline | `/opt/wharfline` (저장소 `deploy/` 방식) | `http(s)://wharfline_domain` |

- 필수 변수와 예시: `group_vars/all/vault.yaml.example`
- 버전: `gitea_version` 28.3.0, `act_runner_version` 0.6.1, `wharfline_version` v2026.11.14-1
- **HTTPS**: `traefik_acme_email` 을 지정하면 Traefik 이 도메인마다 Let's Encrypt 인증서를 받고 갱신하며 HTTP → HTTPS 로 넘깁니다. Gitea ROOT_URL 과 wharfline 쿠키 Secure 도 자동으로 https 기준이 됩니다. (DNS A 레코드가 서버를 가리켜야 함, 로컬 테스트에서는 검증하지 않음)
- **Gitea 관리자**: `gitea_admin`. `admin` 은 Gitea 예약어라 쓸 수 없습니다.
- **act_runner**: 첫 실행 때 토큰을 발급해 자동 등록합니다. 다시 등록하려면 `/opt/gitea/runner.env` 와 `gitea_runner_data` 볼륨을 지우고 재실행하세요.
- **wharfline 마스터 키**: `wharfline_master_key` 를 비워 두면 첫 실행 때 서버에서 만들고 `secrets/<호스트>/wharfline_master_keys` 로 가져옵니다(gitignore). **vault 로 옮기고 로컬 파일은 지우세요.** 잃으면 저장된 비밀 값을 복구할 수 없습니다.
- **wharfline 이미지는 amd64 전용**입니다. ARM 서버에서는 `wharfline_platform: linux/amd64` 로 에뮬레이션 실행할 수 있습니다(느림).

## 04-gitlab
03-gitea 의 GitLab 버전입니다. 구성은 같고 Gitea 대신 GitLab CE + gitlab-runner 가 `/opt/gitlab` 에 뜹니다.

- 버전: `gitlab_version` 19.5.5-ce.0, `gitlab_runner_version` v19.5.3
- **메모리 4GB 이상**. `gitlab_low_memory: true`(기본)는 puma 단일 프로세스, 내장 모니터링 끄기로 메모리를 아낍니다. 8GB 이상이면 false 로.
- **`gitlab_root_password` 는 무작위 문자열로** (`openssl rand -base64 18`). GitLab 은 흔한 단어 조합 비밀번호면 root 를 만들지 않고 조용히 기동합니다. role 이 이를 감지해 다시 만들고, 그래도 안 되면 이유를 보여 주고 중단합니다.
- runner: 첫 실행 때 root 의 단기 토큰(1일, create_runner 권한)으로 인스턴스 러너를 만들어 등록합니다.
- 첫 기동은 5~10분 걸립니다.

## 05-app
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
- 03/04/07 과 같은 Traefik 을 공유하므로 한 서버에 함께 둘 수 있습니다 (02-kubernetes 와는 80/443 이 겹침)

## 06-postgres
- PostgreSQL 18 (`/opt/postgres`), 슈퍼유저 `postgres`
- `postgres_databases` 로 DB/유저 생성, 비밀번호는 실행할 때마다 vault 값으로 맞춤
- **외부 접속은 `postgres_allowed_sources` 의 CIDR 만** 허용합니다. 비우면 서버 내부에서만 접속할 수 있습니다.
- `postgres_settings` 로 `max_connections`, `shared_buffers` 등 설정

### Docker 포트 방화벽 (docker_firewall)
Docker 로 publish 한 포트는 ufw 를 거치지 않습니다. 06/09 는 전용 `ORCA-DOCKER` 체인(DOCKER-USER 에서 연결)에 출발지 제한 규칙을 넣고, `docker-firewall.service` 가 Docker 재시작/재부팅 때마다 다시 적용합니다.
- 규칙 파일: `/etc/docker-firewall/rules.d/*.rules` (`<포트> <프로토콜> <허용 CIDR...>`)
- 확인: `sudo iptables -S ORCA-DOCKER`

## 07-monitoring
| 대상 | 구성 |
|---|---|
| `[monitoring]` | Prometheus (127.0.0.1:9090), Grafana (:3001, Traefik 네트워크에서만 허용 → `grafana_domain`) |
| 모든 서버 (`monitoring_targets`, 기본 all) | node-exporter :9100, cAdvisor :9280 — 모니터링 서버 IP 에서만 접근 허용 |

- Grafana 에 Prometheus 데이터소스와 **Node Exporter Full** 대시보드가 자동으로 들어갑니다 (`grafana_dashboards` 로 추가).
- 서버를 추가하면 07 을 다시 실행하세요. Prometheus 수집 대상이 인벤토리에서 다시 만들어집니다.
- 모든 컨테이너는 host 네트워크라 ufw 규칙을 그대로 따릅니다.

## 08-security
모든 서버에 적용하는 운영용 플레이북입니다. 허용 IP 를 바꿨을 때도 이것만 다시 돌리면 됩니다.

| 항목 | 내용 |
|---|---|
| 방화벽 | ufw 규칙(`firewall_*`)과 Docker 포트 규칙(06/09 의 rules.d) 재적용 |
| SSH | root 로그인 차단, `security_disable_password_auth: true` 면 비밀번호 로그인 차단, MaxAuthTries 4 등 |
| CrowdSec | 엔진은 Docker(`/opt/crowdsec`), 차단기는 호스트 패키지. SSH 로그 + Traefik 액세스 로그로 공격 탐지, 커뮤니티 차단 목록 공유. `INPUT` 과 `DOCKER-USER` 모두 차단해서 Docker 로 연 포트도 보호. `security_whitelist_ips` 로 관리자 IP 제외 |
| 업데이트 | unattended-upgrades 로 보안 업데이트 자동 설치 (`security_auto_reboot` 로 자동 재부팅) |

**잠김 방지**: 비밀번호 로그인을 막으려면 `deploy_user_ssh_keys` 가 있어야 하고, root 로그인을 막으려면 Ansible 이 root 가 아닌 계정으로 접속해야 합니다. 조건이 안 맞으면 실행 전에 중단합니다. 비밀번호 로그인을 막기 전에 **인벤토리를 SSH 키 접속(`ansible_user=manager`, `ansible_ssh_private_key_file=...`)으로 바꾸세요.**

## 09-middleware
- RabbitMQ 4.4 (관리 화면 포함) + Redis 8 (`/opt/middleware`)
- 5672 / 6379 는 `middleware_allowed_sources` 의 CIDR 에서만 접속 가능
- RabbitMQ 관리 화면은 127.0.0.1:15672 에만 → `ssh -L 15672:localhost:15672 manager@서버` 후 http://localhost:15672
- Redis: 비밀번호 필수, AOF 켜짐, `redis_maxmemory`(256mb) + allkeys-lru, `vm.overcommit_memory=1`
- `middleware_rabbitmq_enabled` / `middleware_redis_enabled` 로 하나만 쓸 수 있음

## 10-backup
서버에서 **실행 중인 서비스를 자동 감지**해서 백업합니다.

| 서비스 | 백업 파일 |
|---|---|
| postgres (06) | `postgres-all.sql.gz` (pg_dumpall) |
| gitea (03) | `gitea-db.dump`, `gitea-data.tar.gz` (저장소, 설정) |
| wharfline | `wharfline-db.dump` (마스터 키는 vault 에 따로) |
| gitlab (04) | `gitlab_backup.tar`, `gitlab-config.tar.gz` (gitlab-secrets.json 포함) |
| rabbitmq (09) | `rabbitmq-definitions.json` (유저, 큐, 익스체인지) |
| redis (09) | `redis-dump.rdb` |
| 공통 | `opt-configs.tar.gz` (/opt/*/docker-compose.yml, .env 등) |

```bash
ansible-playbook ... 10-backup.yaml                          # 매일 03:00 자동 백업 설치 (systemd timer)
ansible-playbook ... 10-backup.yaml --tags now               # 지금 즉시 백업
ansible-playbook ... 10-backup.yaml --tags now -e backup_fetch=true   # + backups/<호스트>/ 로 가져오기
```
- 위치: `/var/backups/orca/<시각>/` (`latest` 링크), `backup_keep_days`(7일) 지나면 삭제
- 서버에서 직접: `sudo orca-backup`, 로그: `journalctl -u orca-backup`
- **외부 저장소**: `backup_restic_repository` 를 지정하면 restic 으로 S3 / SFTP / NAS 에도 보냅니다 (일 7, 주 4, 월 6 보관). `backup_restic_password` 를 잃으면 풀 수 없습니다.

## 11-restore
09 로 만든 백업으로 복구합니다. **현재 데이터를 덮어쓰므로** 확인 값과 대상을 꼭 지정해야 실행됩니다.

```bash
# 서버에 있는 최신 백업으로 postgres 복구
ansible-playbook ... 11-restore.yaml --limit db1 -e restore_confirm=yes -e '{"restore_components": ["postgres"]}'

# 특정 시점
... -e restore_from=20261114-030000

# 서버가 망가져 새로 만든 경우: 01 + 해당 프리셋 실행 → 가져온 백업을 올려서 복구
... -e restore_upload_dir=backups/db1/20261114-030000

# restic 저장소에서
... -e restore_restic_snapshot=latest
```
- 구성 요소: `postgres`, `gitea`, `wharfline`, `gitlab`, `rabbitmq`, `redis`
- 서비스는 미리 설치돼 있어야 합니다 (새 서버면 01 + 프리셋 먼저)
- wharfline 은 `wharfline_master_key` 가 백업 당시와 같아야 하고, gitlab 은 `gitlab_version` 이 같아야 합니다

## 12-vpn
- WireGuard (`linuxserver/wireguard`, `/opt/wireguard`), UDP 51820
- `vpn_peers: [laptop, phone]` 처럼 이름만 적으면 접속 설정을 만들고 `secrets/<호스트>/wireguard/<이름>.conf` 로 가져옵니다 (gitignore). 폰은 `docker exec wireguard /app/show-peer <이름>` 의 QR 코드로.
- `[vpn]` 그룹 서버는 08 실행 시 VPN 대역(`10.13.13.0/24`)과 WireGuard 컨테이너 네트워크(`vpn_docker_subnet`, 기본 `172.31.250.0/24`)가 CrowdSec 화이트리스트에 자동으로 들어갑니다. VPN 을 거친 요청이 한 주소로 보여서, 한 명이 걸리면 VPN 사용자 전체가 차단되는 것을 막습니다.
- CrowdSec 허브의 `crowdsecurity/wireguard` 컬렉션은 쓰지 않습니다. WireGuard 는 키가 틀린 패킷에 응답하지 않아 무차별 대입이 성립하지 않고, 이 컬렉션은 커널 디버그 로그를 켜야 해서 CrowdSec 도 사용을 권하지 않습니다.
- 기본은 split tunnel (`vpn_allowed_ips: 10.13.13.0/24`). 06/09 의 `*_allowed_sources` 에 VPN 대역을 넣으면 DB · 미들웨어를 VPN 으로만 쓸 수 있습니다.
- 사람을 추가/삭제하려면 `vpn_peers` 를 바꾸고 다시 실행 (기존 키는 유지)
