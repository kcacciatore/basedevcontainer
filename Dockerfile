ARG ORACLE_VERSION=8
ARG DOCKER_VERSION=19.03.5
ARG DOCKER_COMPOSE_VERSION=alpine-1.25.3

FROM docker:${DOCKER_VERSION} AS docker-cli
FROM docker/compose:${DOCKER_COMPOSE_VERSION} AS docker-compose

FROM container-registry.oracle.com/os/oraclelinux:${ORACLE_VERSION}
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=local
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000
LABEL \
    org.opencontainers.image.authors="quentin.mcgaw@gmail.com" \
    org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.version=$VERSION \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.url="https://github.com/kcacciatore/basedevcontainer" \
    org.opencontainers.image.documentation="https://github.com/kcacciatore/basedevcontainer" \
    org.opencontainers.image.source="https://github.com/kcacciatore/basedevcontainer" \
    org.opencontainers.image.title="Base Dev container" \
    org.opencontainers.image.description="Base Oracle Linux development container for Visual Studio Code Remote Containers development"
WORKDIR /home/${USERNAME}
ENTRYPOINT [ "/bin/zsh" ]
ENV TZ=
# Setup user
RUN groupadd -g 1000 docker1000 && useradd -s /bin/sh -u $USER_UID -g $USER_GID $USERNAME && \
    mkdir -p /etc/sudoers.d && \
    echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME
# Install Alpine packages
RUN dnf install -y -q libstdc++ zsh sudo git wget tar gcc-c++ openssl-devel libcurl-devel make

COPY --from=docker-cli --chown=${USER_UID}:${USER_GID} /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker-compose --chown=${USER_UID}:${USER_GID} /usr/local/bin/docker-compose /usr/local/bin/docker-compose
ENV DOCKER_BUILDKIT=1
# All possible docker host groups
RUN ([ ${USER_GID} = 1000 ] || (groupadd -f -g 1000 docker1000 && usermod -a -G docker1000 ${USERNAME} )) && \
    groupadd -f -g 976 docker976 && \
    groupadd -f -g 102 docker102 && \
    usermod -a -G docker976 ${USERNAME}  && \
    usermod -a -G docker102 ${USERNAME} 
# Setup shells
ENV EDITOR=nano \
    LANG=en_US.UTF-8
RUN dnf install shadow-utils && \
    usermod --shell /bin/zsh root && \
    usermod --shell /bin/zsh ${USERNAME} && \
    dnf remove shadow-utils
COPY --chown=${USER_UID}:${USER_GID} shell/.p10k.zsh shell/.zshrc shell/.welcome.sh /home/${USERNAME}/
RUN ln -s /home/${USERNAME}/.p10k.zsh /root/.p10k.zsh && \
    cp /home/${USERNAME}/.zshrc /root/.zshrc && \
    cp /home/${USERNAME}/.welcome.sh /root/.welcome.sh && \
    sed -i "s/HOMEPATH/home\/${USERNAME}/" /home/${USERNAME}/.zshrc && \
    sed -i "s/HOMEPATH/root/" /root/.zshrc
RUN git clone --single-branch --depth 1 https://github.com/robbyrussell/oh-my-zsh.git /home/${USERNAME}/.oh-my-zsh &> /dev/null && \
    git clone --single-branch --depth 1 https://github.com/romkatv/powerlevel10k.git /home/${USERNAME}/.oh-my-zsh/custom/themes/powerlevel10k &> /dev/null && \
    rm -rf /home/${USERNAME}/.oh-my-zsh/custom/themes/powerlevel10k/.git && \
    chown -R ${USERNAME}:${USER_GID} /home/${USERNAME}/.oh-my-zsh && \
    chmod -R 700 /home/${USERNAME}/.oh-my-zsh && \
    cp -r /home/${USERNAME}/.oh-my-zsh /root/.oh-my-zsh && \
    chown -R root:root /root/.oh-my-zsh
USER ${USERNAME}