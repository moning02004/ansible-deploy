# 테스트용 대상 서버: systemd 가 PID 1 로 도는 Ubuntu
ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}
# 테스트 속도를 위한 apt 미러 (빈 값이면 이미지 기본 미러). 실제 서버 설정에는 영향 없음
ARG APT_MIRROR=http://ftp.kaist.ac.kr
ENV DEBIAN_FRONTEND=noninteractive
RUN if [ -n "$APT_MIRROR" ]; then \
      sed -i -E "s#http://(ports\.ubuntu\.com|archive\.ubuntu\.com|security\.ubuntu\.com)#${APT_MIRROR}#g" \
        /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list 2>/dev/null || true; \
    fi \
 && apt-get update \
 && apt-get install -y --no-install-recommends systemd systemd-sysv python3 sudo iptables ca-certificates \
 && apt-get clean && rm -rf /var/lib/apt/lists/*
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
