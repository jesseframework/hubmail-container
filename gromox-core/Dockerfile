# syntax=docker/dockerfile:1
# HubMail: our admin-api fork, overlaid onto the packaged grommunio-admin-api below.
FROM alpine/git:latest AS hubmail-admin-api
ARG HUBMAIL_ADMIN_API_REPO=https://github.com/jesseframework/hubmail-admin-api.git
ARG HUBMAIL_ADMIN_API_REF=master
RUN git clone --depth 1 --branch "${HUBMAIL_ADMIN_API_REF}" "${HUBMAIL_ADMIN_API_REPO}" /src && \
    git -C /src rev-parse HEAD > /src/.hubmail-commit

# Container image with openSUSE Leap + supervisord
#
# Description:
#
# This image runs grommunio-core services using supervisord as PID 1,
# eliminating the need for systemd, privileged mode, and sysbox runtime.

FROM opensuse/leap:16.0

ARG GROMMUNIO_REPO=openSUSE_Leap_16.0

RUN zypper -n install -y \
        iptables   \
        iproute2    \
        kmod       \
        curl    \
        patterns-base-apparmor \
        patterns-base-base \
        procps  \
        sudo       \
        cronie     \
        bind-utils \
        timezone   \
        nano       \
        lsof

# Default timezone — can be overridden at runtime via the TIMEZONE env var in var.env
RUN ln -sf /usr/share/zoneinfo/Europe/Vienna /etc/localtime && \
    echo "Europe/Vienna" > /etc/timezone

RUN	curl https://download.grommunio.com/RPM-GPG-KEY-grommunio > gr.key && \
	  rpm --import gr.key && \
	  zypper --non-interactive --quiet ar -C https://download.grommunio.com/community/${GROMMUNIO_REPO} grommunio && \
	  zypper --gpg-auto-import-keys ref && \
	  zypper -n refresh grommunio

# Install grommunio packages (retry up to 3 times for transient download errors)
RUN    zypper --non-interactive install -y vim mysql nginx \
         gromox grommunio-admin-api grommunio-admin-web grommunio-antispam \
         grommunio-common grommunio-web grommunio-sync grommunio-dav postfix postfix-mysql \
         grommunio-chat grommunio-keycloak grommunio-auth cyrus-sasl-saslauthd cyrus-sasl-plain jq redis \
       || { echo "Retry 1..."; zypper clean -a; sleep 5; \
            zypper --non-interactive install -y vim mysql nginx \
              gromox grommunio-admin-api grommunio-admin-web grommunio-antispam \
              grommunio-common grommunio-web grommunio-sync grommunio-dav postfix postfix-mysql \
              grommunio-chat grommunio-keycloak grommunio-auth cyrus-sasl-saslauthd cyrus-sasl-plain jq redis; } \
       || { echo "Retry 2..."; zypper clean -a; sleep 10; \
            zypper --non-interactive install -y vim mysql nginx \
              gromox grommunio-admin-api grommunio-admin-web grommunio-antispam \
              grommunio-common grommunio-web grommunio-sync grommunio-dav postfix postfix-mysql \
              grommunio-chat grommunio-keycloak grommunio-auth cyrus-sasl-saslauthd cyrus-sasl-plain jq redis; }

# HubMail overlay: replace the packaged admin-api code with our fork (keeps the
# packaged config.yaml / api-config.ini). Carries the 5-user cap removal.
COPY --from=hubmail-admin-api /src/api /usr/share/grommunio-admin-api/api
COPY --from=hubmail-admin-api /src/cli /usr/share/grommunio-admin-api/cli
COPY --from=hubmail-admin-api /src/endpoints /usr/share/grommunio-admin-api/endpoints
COPY --from=hubmail-admin-api /src/orm /usr/share/grommunio-admin-api/orm
COPY --from=hubmail-admin-api /src/res /usr/share/grommunio-admin-api/res
COPY --from=hubmail-admin-api /src/services /usr/share/grommunio-admin-api/services
COPY --from=hubmail-admin-api /src/tools /usr/share/grommunio-admin-api/tools
COPY --from=hubmail-admin-api /src/main.py /usr/share/grommunio-admin-api/main.py
COPY --from=hubmail-admin-api /src/.hubmail-commit /etc/hubmail/admin-api.commit

# Browsers can send >4 KiB of headers (cookies); uWSGI's default 4096-byte buffer
# then resets the connection and the admin UI shows "Could not connect to backend".
RUN grep -q '^buffer-size' /usr/share/grommunio-admin-api/api-config.ini || \
    sed -i '/^\[uwsgi\]/a buffer-size = 32768' /usr/share/grommunio-admin-api/api-config.ini

# Record the exact grommunio package versions baked into this image; the
# community repo only serves the latest build, so this is our version record.
RUN mkdir -p /etc/hubmail && \
    rpm -qa --qf '%{NAME} %{VERSION}-%{RELEASE}\n' | grep -E '^(gromox|grommunio|libexmdbpp|php8-mapi)' | sort > /etc/hubmail/packages.txt && \
    cat /etc/hubmail/packages.txt

# Install Certbot from openSUSE 16 packages + iconv modules (iso-2022-jp etc.)
RUN    zypper -n install -y python313-certbot python313-certbot-nginx glibc-gconv-modules-extra

# Install supervisord (Python 3.13 is the system default on openSUSE Leap 16)
RUN zypper -n install -y python313-pip && \
    pip3.13 install --no-cache-dir supervisor

# Create default user if needed
RUN    groupadd 'wheel' &&                         \
    useradd -m -s /bin/bash -G wheel admin && echo "admin:admin" | chpasswd

COPY gromox-core/scripts /home/scripts
COPY gromox-core/common /home/common
COPY gromox-core/config /home/config

RUN chmod +x /home/scripts/db.sh

COPY gromox-core/entrypoint.sh /home/entrypoint.sh
RUN chmod +x /home/entrypoint.sh

COPY gromox-core/docker-entrypoint.sh /home/docker-entrypoint.sh
RUN chmod +x /home/docker-entrypoint.sh

COPY gromox-core/supervisord.conf /etc/supervisord.conf
COPY gromox-core/supervisor.d /etc/supervisor.d

LABEL org.opencontainers.image.title="hubmail-core" \
      org.opencontainers.image.description="HubMail: grommunio groupware core with HubMail patches" \
      org.opencontainers.image.source="https://github.com/jesseframework/hubmail-container" \
      org.opencontainers.image.licenses="AGPL-3.0-or-later"

ENTRYPOINT ["/home/docker-entrypoint.sh"]
