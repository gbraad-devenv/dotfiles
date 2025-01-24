#!/bin/zsh

CONFIG="${HOME}/.devenv"
alias devini="git config -f $CONFIG"

devenv() {
  if [ $# -lt 2 ]; then
    echo "Usage: $0 <prefix> <command> [args...]"
    return 1
  fi

  local PREFIX=$1
  local COMMAND=$2
  shift 2

  local START_SHELL=$(devini --get devenv.shell)
  local START_ARGS=(
    "--user=root"
    "--systemd=always"
    "--cap-add=NET_RAW"
    "--cap-add=NET_ADMIN"
    "--cap-add=SYS_ADMIN"
    "--device=/dev/net/tun"
    "--device=/dev/fuse"
    "--userns=keep-id"
    #"--pull=newer"
  )
  # issue as some containers do not have this yet
  #"--workdir=$(devini --get devenv.workdir)"
  local START_PATHS=(
    "-v" "~/Projects:/home/${USER}/Projects"
    "-v" "~/Projects:/var/home/${USER}/Projects"
  )

  case "$COMMAND" in
    "env" | "run")
      podman run --rm -it --hostname ${HOSTNAME}-${PREFIX}env --entrypoint='' \
        "${START_ARGS[@]}" "${START_PATHS[@]}" \
        $(generate_image_name $PREFIX) ${START_SHELL}
      ;;
    "sys" | "system" | "create")
      for (( i=0; i < ${#START_PATHS[@]}; i++ )); do
        START_PATHS[$i]="${START_PATHS[$i]/#\~/$HOME}"
      done
      podman run -d --name=${PREFIX}sys --hostname ${HOSTNAME}-${PREFIX}sys \
        "${START_ARGS[@]}" "${START_PATHS[@]}" \
        $(generate_image_name $PREFIX)
      # TODO: systemd only when able to check for running state
      #&& (mkdir -p ${HOME}/.config/systemd/user && cd ${HOME}/.config/systemd/user \
      #&& podman generate systemd --name --files ${PREFIX}sys) \
      #&& systemctl --user daemon-reload \
      #&& systemctl --user start container-${PREFIX}sys
      ;;
    "start")
      if (! podman ps -a --format "{{.Names}}" | grep -q ${PREFIX}sys); then
        dev ${PREFIX} sys
      else
        podman start ${PREFIX}sys
      fi
      #systemctl --user start container-${PREFIX}sys
      ;;
    "stop")
      #systemctl --user stop container-${PREFIX}sys
      podman stop ${PREFIX}sys
      ;;
    "kill" | "rm" | "remove")
      #systemctl --user stop container-${PREFIX}sys
      podman rm -f ${PREFIX}sys
      ;;
    "exec" | "execute")
      if (! podman ps -a --format "{{.Names}}" | grep -q ${PREFIX}sys); then
        dev ${PREFIX} sys
        sleep 1
      fi
      if (podman ps --filter "name=${PREFIX}sys" --filter "status=stopped" | grep -q ${PREFIX}sys); then
        dev ${PREFIX} start
        sleep 2
      fi
      podman exec -it ${PREFIX}sys $@
      ;;
    "root" | "su")
      dev ${PREFIX} exec ${START_SHELL}
      ;;
    "user" | "sh" | "shell")
      dev ${PREFIX} exec su - gbraad $*
      ;;
    "sysctl" | "systemctl" | "systemd")
      if (podman ps --filter "name=${PREFIX}sys" --filter "status=stopped" | grep -q ${PREFIX}sys); then
        echo "${PREFIX}sys not running"
        return
      fi
      if (! podman ps -a --format "{{.Names}}" | grep -q ${PREFIX}sys); then
        echo "${PREFIX}sys not created"
        return
      fi

      dev ${PREFIX} exec systemctl $@
      ;;
    "ps")
      dev ${PREFIX} exec ps -ax $@
      ;;
    "status")
      dev ${PREFIX} sysctl status $@
      ;;
    "tmux")
      command="-c tmux -2 $@"
      dev ${PREFIX} user $command
      ;;
    *)
      echo "Unknown command: $0 $PREFIX $COMMAND"
      ;;
  esac
}


generate_image_name() {
  local PREFIX=$1
  local IMAGE=$(devini --get "images.${PREFIX}")

  if [ -z "${IMAGE}" ]; then
    echo "Unknown distro: $PREFIX"
    exit 1
  fi

  echo ${IMAGE}
}

# legacy aliases

generate_aliases() {
  local PREFIX=$1
  alias ${PREFIX}env="devenv ${PREFIX} env"
  alias ${PREFIX}sys="devenv ${PREFIX} sys"
  alias ${PREFIX}root="devenv ${PREFIX} root"
  alias ${PREFIX}user="devenv ${PREFIX} user"
  alias ${PREFIX}tmux="devenv ${PREFIX} tmux"
  alias ${PREFIX}build="devenv ${PREFIX} tmux attach-session -t build || dev ${PREFIX} tmux new-session -s build"
}

if [[ $(devini --get "devenv.aliases") == true ]]; then
  alias dev="devenv"

  generate_aliases "fed"
  generate_aliases "deb"
  generate_aliases "alp"
  generate_aliases "cen"
  generate_aliases "go"
  generate_aliases "ubi"
  generate_aliases "ubu"
  generate_aliases "alm"
  generate_aliases "sus"
  generate_aliases "tum"

  # Base on host distro
  source /etc/os-release
  case "$ID" in
    "fedora" | "bazzite")
        alias devsys="fedsys"
        alias devroot="fedroot"
        alias devuser="feduser"
        alias devtmux="fedtmux"
        ;;
    "debian" | "ubuntu")
        alias devsys="debsys"
        alias devroot="debroot"
        alias devuser="debuser"
        alias devtmux="debtmux"
        ;;
  esac
fi
