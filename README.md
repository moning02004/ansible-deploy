# ansible-deploy — 플레이북 책장

서버 용도별 프리셋 플레이북 모음입니다. 2번 이후는 모두 `01-base` 위에 쌓습니다.

| # | 플레이북 | 내용 | 상태 |
|---|---|---|---|
| 01 | `01-base.yaml` | 공통 설정, deploy 유저, ufw, Docker, docker rollout | ✅ |
| 02 | `02-gitea.yaml` | base + Gitea + act_runner + wharfline + nginx | ⬜ |
| 03 | `03-gitlab.yaml` | base + GitLab CE + gitlab-runner + wharfline + nginx | ⬜ |
| 04 | `04-app.yaml` | base + nginx + 배포 디렉터리 (CI가 배포하는 대상 서버) | ⬜ |
| 05 | `05-postgres.yaml` | base + PostgreSQL | ⬜ |
| 06 | `06-monitoring.yaml` | Prometheus + Grafana, 모든 서버에 node-exporter / cAdvisor | ⬜ |
| 07 | `07-security.yaml` | 방화벽 규칙 재적용, fail2ban, SSH 강화 (단독 실행용) | ⬜ |
| 08 | `08-middleware.yaml` | RabbitMQ + Redis | ⬜ |
| 09 | `09-backup.yaml` | 자동 백업 스케줄 설치(`--tags schedule`) / 즉시 백업(`--tags now`) | ⬜ |
| 10 | `10-restore.yaml` | 백업 파일로 복구 | ⬜ |

## 환경
- ansible-core 2.18 이상
- 대상 서버: Ubuntu / Debian
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
