#!/usr/bin/env bash
# 플레이북 컨테이너 테스트
#   tests/run.sh 01-base            실행 → 멱등성(2회차 changed=0) → verify
#   tests/run.sh 01-base --keep     끝난 뒤 컨테이너 유지 (docker exec -it orca-ansible-test bash)
#   UBUNTU_VERSION=22.04 tests/run.sh 01-base
set -euo pipefail

PB="${1:?사용법: tests/run.sh <플레이북 이름, 예: 01-base> [--keep]}"
PB="${PB%.yaml}"
KEEP="${2:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME=orca-ansible-test
UBUNTU_VERSION="${UBUNTU_VERSION:-24.04}"
IMAGE="orca-ansible-test:${UBUNTU_VERSION}"

[[ -f "$ROOT/$PB.yaml" ]] || { echo "없는 플레이북: $PB.yaml"; exit 1; }
[[ -f "$ROOT/tests/verify/$PB.yaml" ]] || { echo "verify 파일 없음: tests/verify/$PB.yaml"; exit 1; }

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

WORK="$(mktemp -d)"
cleanup() {
  rm -rf "$WORK"
  if [[ "$KEEP" != "--keep" ]]; then docker rm -f "$NAME" >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT

log "이미지 빌드 ($IMAGE)"
docker build -q --build-arg UBUNTU_VERSION="$UBUNTU_VERSION" -t "$IMAGE" "$ROOT/tests" >/dev/null

log "테스트 컨테이너 시작"
docker rm -f "$NAME" >/dev/null 2>&1 || true
# /var/lib/docker, containerd 를 볼륨으로 빼야 컨테이너 안 Docker 가 overlayfs 를 쓸 수 있음
docker run -d --name "$NAME" --hostname "$NAME" \
  --privileged --cgroupns=host -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  -v /var/lib/docker -v /var/lib/containerd \
  "$IMAGE" >/dev/null
for _ in $(seq 30); do
  state="$(docker exec "$NAME" systemctl is-system-running 2>/dev/null || true)"
  [[ "$state" == running || "$state" == degraded ]] && break
  sleep 1
done

# vault 비밀번호 없이 돌리기 위해 암호화된 변수 파일을 뺀 사본에서 실행
rsync -a --exclude .git --exclude 'group_vars/all/vault.yaml' "$ROOT/" "$WORK/"
cd "$WORK"
export ANSIBLE_CONFIG="$WORK/ansible.cfg" ANSIBLE_FORCE_COLOR=1
ARGS=(-i tests/inventory.ini -e @tests/vars.yaml)

log "1회차 실행: $PB.yaml"
ansible-playbook "${ARGS[@]}" "$PB.yaml"

log "2회차 실행: 멱등성 확인"
ansible-playbook "${ARGS[@]}" "$PB.yaml" | tee "$WORK/second.log"
if ! grep -Eq 'changed=0 .*failed=0' "$WORK/second.log"; then
  echo "✗ 멱등성 실패: 2회차 실행에서 changed 가 0 이 아닙니다"; exit 1
fi

log "verify: tests/verify/$PB.yaml"
ansible-playbook "${ARGS[@]}" "tests/verify/$PB.yaml"

log "✓ $PB 테스트 통과"
