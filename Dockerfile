FROM jenkins/jenkins:2.462.3-lts-jdk17
USER root
RUN apt-get update && apt-get install -y --no-install-recommends lsb-release ca-certificates curl gnupg \
  && curl -fsSL https://download.docker.com/linux/debian/gpg -o /usr/share/keyrings/docker-archive-keyring.asc \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list \
  && apt-get update && apt-get install -y --no-install-recommends docker-ce-cli \
  && apt-get clean && rm -rf /var/lib/apt/lists/*
USER jenkins
# NOTE: Blue Ocean is deprecated and no longer installed by default.
# Install only maintained plugins; pin versions via plugins.txt in CI.
RUN jenkins-plugin-cli --plugins "docker-workflow git workflow-aggregator"
