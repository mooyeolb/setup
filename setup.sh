#!/usr/bin/env bash
set -e

DEFAULT_GIT_URL="git@github.com:mooyeolb/dotfiles.git"
if [ -z "$GIT_URL" ]; then
  GIT_URL=$DEFAULT_GIT_URL
fi

mirror=""
DRY_RUN=${DRY_RUN:-}
while [ $# -gt 0 ]; do
  case "$1" in
  --mirror)
    mirror="$2"
    shift
    ;;
  --dry-run)
    DRY_RUN=1
    ;;
  --*)
    echo "Illegal option $1"
    ;;
  esac
  shift $(($# > 0 ? 1 : 0))
done

case "$mirror" in
es)
  GIT_URL="git@es.naverlabs.com:mooyeol-b/dotfiles.git"
  ;;
esac

command_exists() {
  command -v "$@" >/dev/null 2>&1
}

is_dry_run() {
  if [ -z "$DRY_RUN" ]; then
    return 1
  else
    return 0
  fi
}

get_distribution() {
  lsb_dist=""
  # Every system that we officially support has /etc/os-release
  if [ -r /etc/os-release ]; then
    lsb_dist="$(. /etc/os-release && echo "$ID")"
  fi
  # Returning an empty string here should be alright since the
  # case statements don't act unless you provide an actual value
  echo "$lsb_dist"
}

do_install() {
  echo "# Executing system setup script"

  if command_exists config; then
    cat >&2 <<-'EOF'
			Warning: the "config" command appears to already exist on this system.
			You may press Ctrl+C now to abort this script.
		EOF
    (
      set -x
      sleep 20
    )
  fi

  user="$(id -un 2>/dev/null || true)"

  sh_c='sh -c'
  sh_c_local='sh -c'
  if [ "$user" != 'root' ]; then
    if command_exists sudo; then
      sh_c='sudo -E sh -c'
    elif command_exists su; then
      sh_c='su -c'
    else
      cat >&2 <<-'EOF'
				Error: this installer needs the ability to run commands as root.
				We are unable to find either "sudo" or "su" available to make this happen.
			EOF
      exit 1
    fi
  fi

  if is_dry_run; then
    sh_c='echo'
    sh_c_local='echo'
  fi

  # perform some very rudimentary platform detection
  lsb_dist=$(get_distribution)
  lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"

  case "$lsb_dist" in
  ubuntu)
    if command_exists lsb_release; then
      dist_version="$(lsb_release --codename | cut -f2)"
    fi
    if [ -z "$dist_version" ] && [ -r /etc/lsb-release ]; then
      dist_version="$(. /etc/lsb-release && echo "$DISTRIB_CODENAME")"
    fi
    ;;
  *)
    if command_exists lsb_release; then
      dist_version="$(lsb_release --release | cut -f2)"
    fi
    if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
      dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
    fi
    ;;
  esac

  # Run setup for each distro accordingly
  case "$lsb_dist" in
  ubuntu)
    pre_reqs=(
      software-properties-common
      zsh
      ca-certificates
      curl
      git
      ripgrep
      cmake
      glslang-tools
      libtool
      golang
      git-delta
      ffmpeg
      fzf
      bat
      exa
    )
    if ! command -v gpg >/dev/null; then
      pre_reqs+=(gnupg)
    fi
    (
      if ! is_dry_run; then
        set -x
      fi
      $sh_c "apt-get update -qq >/dev/null"
      $sh_c "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq" "${pre_reqs[@]}" ">/dev/null"
    )
    ;;
  fedora)
    pkg_manager="dnf"
    pre_reqs_group=(
      \"C Development Tools and Libraries\"
    )
    pre_reqs=(
      zsh
      util-linux-user
      curl
      git
      ripgrep
      cmake
      glslang
      libtool
      python-devel
      golang
      git-delta
      ffmpeg
      fzf
      bat
      exa
    )
    (
      if ! is_dry_run; then
        set -x
      fi
      $sh_c "$pkg_manager groupinstall -y -q" "${pre_reqs_group[@]}"
      $sh_c "$pkg_manager install -y -q" "${pre_reqs[@]}"
    )
    ;;
  *)
    echo
    echo "ERROR: Unsupported distribution '$lsb_dist'"
    echo
    exit 1
    ;;
  esac

  # docker
  if ! command -v docker &>/dev/null; then
    $sh_c "wget -qO- https://get.docker.com | /bin/bash"
  fi

  # nvm
  nvm_home="/home/${user}/.share/nvm"
  if [ ! -d "$nvm_home" ]; then
    $sh_c_local "wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | /bin/bash"
  fi

  # mambaforge
  mambaforge_home="/home/${user}/.share/mambaforge"
  if [ ! -d "$mambaforge_home" ]; then
    $sh_c_local "wget -N -P /tmp/ https://github.com/conda-forge/miniforge/releases/latest/download/Mambaforge-$(uname)-$(uname -m).sh"
    $sh_c_local "bash /tmp/Mambaforge-$(uname)-$(uname -m).sh -bfs -p $mambaforge_home"
    $sh_c_local "rm /tmp/Mambaforge-$(uname)-$(uname -m).sh"
  fi

  exit 0
}

# wrapped up in a function so that we have some protection against only getting
# half the file during "curl | sh"
do_install
