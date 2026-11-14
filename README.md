# ansible-deploy — 플레이북 책장

서버 용도별 프리셋 플레이북 모음입니다. 2번 이후는 모두 `01-base` 위에 쌓습니다.

| # | 플레이북 | 내용 | 상태 |
|---|---|---|---|
| 01 | `01-base.yaml` | 공통 설정, deploy 유저, ufw, Docker, docker rollout | ✅ |
| 02 | `02-gitea.yaml` | base + Gitea + act_runner + wharfline + nginx | ✅ |
| 03 | `03-gitlab.yaml` | base + GitLab CE + gitlab-runner + wharfline + nginx | ✅ |
| 04 | `04-app.yaml` | base + Traefik + 배포 디렉터리 (CI가 배포하는 대상 서버, docker rollout 무중단 배포) | ⬜ |
| 05 | `05-postgres.yaml` | base + PostgreSQL | ⬜ |
| 06 | `06-monitoring.yaml` | Prometheus + Grafana, 모든 서버에 node-exporter / cAdvisor | ⬜ |
| 07 | `07-security.yaml` | 방화벽 규칙 재적용, fail2ban, SSH 강화, 보안 업데이트 자동 설치 (단독 실행용) | ⬜ |
| 08 | `08-middleware.yaml` | RabbitMQ + Redis | ⬜ |
| 09 | `09-backup.yaml` | 자동 백업 스케줄 설치(`--tags schedule`) / 즉시 백업(`--tags now`) | ⬜ |
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
| Gitea + Postgres + act_runner | `/opt/gitea` (compose) | `http(s)://gitea_domain`, SSH `2222` |
| wharfline | `/opt/wharfline` (저장소 `deploy/` 방식) | `http(s)://wharfline_domain` |

- 필수 변수와 예시: `group_vars/all/vault.yaml.example`
- 버전: `gitea_version` 28.3.0, `act_runner_version` 0.6.1, `wharfline_version` v2026.11.14-1
- **HTTPS**: `nginx_certbot_email` 을 지정하면 도메인마다 Let's Encrypt 인증서를 받고 HTTP → HTTPS 로 넘깁니다. Gitea ROOT_URL 과 wharfline 쿠키 Secure 도 자동으로 https 기준이 됩니다. (DNS A 레코드가 서버를 가리켜야 함, 로컬 테스트에서는 검증하지 않음)
- **Gitea 관리자**: `gitea_admin`. `admin` 은 Gitea 예약어라 쓸 수 없습니다.
- **act_runner**: 첫 실행 때 토큰을 발급해 자동 등록합니다. 다시 등록하려면 `/opt/gitea/runner.env` 와 `gitea_runner_data` 볼륨을 지우고 재실행하세요.
- **wharfline 마스터 키**: `wharfline_master_key` 를 비워 두면 첫 실행 때 서버에서 만들고 `secrets/<호스트>/wharfline_master_keys` 로 가져옵니다(gitignore). **vault 로 옮기고 로컬 파일은 지우세요.** 잃으면 저장된 비밀 값을 복구할 수 없습니다.
- **wharfline 이미지는 amd64 전용**입니다. ARM 서버에서는 `wharfline_platform: linux/amd64` 로 에뮬레이션 실행할 수 있습니다(느림).

## 03-gitlab
02-gitea 의 GitLab 버전입니다. 구성은 같고 Gitea 대신 GitLab CE + gitlab-runner 가 `/opt/gitlab` 에 뜹니다.

- 버전: `gitlab_version` 19.5.5-ce.0, `gitlab_runner_version` v19.5.3
- **메모리 4GB 이상**. `gitlab_low_memory: true`(기본)는 puma 단일 프로세스, 내장 모니터링 끄기로 메모리를 아낍니다. 8GB 이상이면 false 로.
- **`gitlab_root_password` 는 무작위 문자열로** (`openssl rand -base64 18`). GitLab 은 흔한 단어 조합 비밀번호면 root 를 만들지 않고 조용히 기동합니다. role 이 이를 감지해 다시 만들고, 그래도 안 되면 이유를 보여 주고 중단합니다.
- runner: 첫 실행 때 root 의 단기 토큰(1일, create_runner 권한)으로 인스턴스 러너를 만들어 등록합니다.
- 첫 기동은 5~10분 걸립니다.
