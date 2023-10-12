FROM boyzwj1984/develop-env:debug

ARG GIT_USER_NAME
ENV GIT_USER_NAME=${GIT_USER_NAME}\
  ERL_AFLAGS="-kernel shell_history enabled"

RUN git config --global --add safe.directory /ws/gc_chat

WORKDIR /ws/gc_chat