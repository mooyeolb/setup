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
			cmake
			unzip
			libtool
			golang
			ffmpeg
		)

		case "$dist_version" in
		bionic)
			;;
		jammy)
			pre_reqs+=(
				ripgrep
				glslang-tools
				fzf
				bat
				exa
			)
			;;
		*)
			;;
		esac

		if ! command_exists gpg; then
			pre_reqs+=(gnupg)
		fi
		(
			if ! is_dry_run; then
				set -x
			fi
			$sh_c "apt-get update -qq >/dev/null"
			$sh_c "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq" "${pre_reqs[@]}" ">/dev/null"
		)
		ZSHENV="/etc/zsh/zshenv"
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
			unzip
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
		ZSHENV="/etc/zshenv"
		;;
	*)
		echo
		echo "ERROR: Unsupported distribution '$lsb_dist'"
		echo
		exit 1
		;;
	esac

	# ripgrep
	if ! command_exists rg; then
		$sh_c_local "curl -LO https://github.com/BurntSushi/ripgrep/releases/download/13.0.0/ripgrep-13.0.0-x86_64-unknown-linux-musl.tar.gz"
		$sh_c_local "tar xf ripgrep-13.0.0-*.tar.gz"
		$sh_c_local "cp ripgrep-13.0.0-*/rg ${HOME}/.local/bin/rg"
		# TODO: ripgrep completion, man
	fi

	# glslang-tools

	# fzf
	if ! command_exists fzf; then
		$sh_c_local "git clone --depth 1 https://github.com/junegunn/fzf.git ${HOME}/.config/fzf"
		$sh_c_local "${HOME}/.config/fzf/install --xdg --key-bindings --completion --update-rc --no-bash --no-fish"
	fi

	# bat
	if command_exists batcat && ! command_exists bat; then
		$sh_c_local "ln -s /usr/bin/batcat ${HOME}/.local/bin/bat"
	fi
	if ! command_exists bat; then
		$sh_c_local "curl -LO https://github.com/sharkdp/bat/releases/download/v0.20.0/bat-v0.20.0-x86_64-unknown-linux-musl.tar.gz"
		$sh_c_local "tar xf bat-v0.20.0-*.tar.gz"
		$sh_c_local "cp bat-v0.20.0-*/bat ${HOME}/.local/bin/bat"
		# TODO: bat completion, man
	fi

	# exa
	if ! command_exists exa; then
		$sh_c_local "curl -LO https://github.com/ogham/exa/releases/download/v0.10.0/exa-linux-x86_64-v0.10.0.zip"
		$sh_c_local "unzip -a exa-linux-x86_64-v0.10.0.zip -d exa-linux-x86_64-v0.10.0"
		$sh_c_local "cp exa-linux-x86_64-v0.10.0/bin/exa ${HOME}/.local/bin/exa"
		# TODO: exa completion, man
	fi

	# git-delta
	if ! command_exists delta; then
		$sh_c_local "curl -LO https://github.com/dandavison/delta/releases/download/0.12.1/delta-0.12.1-x86_64-unknown-linux-musl.tar.gz"
		$sh_c_local "tar xf delta-0.12.1-*.tar.gz"
		$sh_c_local "cp delta-0.12.1-*/delta ${HOME}/.local/bin/delta"
	fi
	if [ ! -f "${HOME}/.config/git/config" ]; then
		$sh_c_local "mkdir -p ${HOME}/.config/git/"
		$sh_c_local "touch ${HOME}/.config/git/config"
	fi
	if ! grep -qxF "        pager = delta" "${HOME}/.config/git/config" >/dev/null; then
		$sh_c_local "{
			echo \"[core]\"
			echo \"        pager = delta\"
			echo \"\"
			echo \"[interactive]\"
			echo \"        diffFilter = delta --color-only\"
			echo \"\"
			echo \"[delta]\"
			echo \"        navigate = true  # use n and N to move between diff sections\"
			echo \"\"
			echo \"[merge]\"
			echo \"        conflictstyle = diff3\"
			echo \"\"
			echo \"[diff]\"
			echo \"        colorMoved = default\"
		} | sudo tee -a \"${HOME}/.config/git/config\" > /dev/null"
	fi

	# zsh
	if ! echo "${SHELL}" | grep -Eq ".*/zsh"; then
		if [ "${lsb_dist}" == "ubuntu" ] && [ "${dist_version}" == "bionic" ]; then
			$sh_c_local "chsh -s $(which zsh) ${user}"
		else
			$sh_c "chsh -s $(which zsh) ${user}"
		fi
	fi
	if [ ! -d "${HOME}/.cache/zsh" ]; then
		$sh_c_local "mkdir -p ${HOME}/.cache/zsh"
	fi
	if ! grep -qxF "# zsh data directory" "${ZSHENV}" >/dev/null; then
		$sh_c_local "{
			echo \"\"
			echo \"# zsh data directory\"
			echo \"export ZDOTDIR=\\\"\${HOME}/.config/zsh\\\"\"
		} | sudo tee -a \"${ZSHENV}\" > /dev/null"
	fi

	# gnupg
	if ! grep -qxF "# gnupg" "${ZSHENV}" >/dev/null; then
		$sh_c_local "{
			echo \"\"
			echo \"# gnupg\"
			echo \"export GNUPGHOME=\\\"\${HOME}/.local/share/gnupg\\\"\"
		} | sudo tee -a \"${ZSHENV}\" > /dev/null"
	fi

	# sheldon
	if ! command_exists sheldon; then
		$sh_c_local "curl --proto '=https' -fLsS https://rossmacarthur.github.io/install/crate.sh \
			| bash -s -- --repo rossmacarthur/sheldon --to ${HOME}/.local/bin"
	fi

	# dotfiles
	DOTFILES_PATH="${HOME}/.local/share/git-dotfiles"
	config="/usr/bin/git --git-dir=${DOTFILES_PATH} --work-tree=${HOME}"
	if [ ! -d "${DOTFILES_PATH}" ]; then
		$sh_c_local "git clone --bare ${GIT_URL} ${DOTFILES_PATH}"
		$sh_c_local "grep -qxF ${DOTFILES_PATH} ${ZSHENV} || echo ${DOTFILES_PATH} >> ${DOTFILES_PATH}/info/exclude"
		if ${config} checkout >/dev/null 2>/dev/null; then
			echo '# Checked out config.';
		else
			echo '# Backing up pre-existing dot files.';
			$sh_c_local "mkdir -p $HOME/.config-backup"
			$sh_c_local "${config} checkout 2>&1 | egrep '\s+\.' | awk {'print \$1'} | xargs -I{} dirname ${HOME}/.config-backup/{} | xargs -I{} mkdir -p {}"
			$sh_c_local "${config} checkout 2>&1 | egrep '\s+\.' | awk {'print \$1'} | xargs -I{} mv ${HOME}/{} ${HOME}/.config-backup/{}"
		fi
		$sh_c_local "${config} checkout"
		$sh_c_local "${config} submodule update --init"
		$sh_c_local "${config} config status.showUntrackedFiles no"
	fi
	if [ -f "${HOME}/.ssh/config" ]; then
		$sh_c_local "chmod 600 ${HOME}/.ssh/config"
	fi

	# docker
	if ! command_exists docker; then
		$sh_c "wget -qO- https://get.docker.com | /bin/bash"
	fi

	# kubectl
	if ! command_exists kubectl; then
		$sh_c_local "curl -LO \"https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\""
		$sh_c_local "chmod +x kubectl"
		$sh_c_local "mkdir -p ${HOME}/.local/bin"
		$sh_c_local "mv ./kubectl ${HOME}/.local/bin/kubectl"
	fi

	# nvm
	nvm_home="${HOME}/.config/nvm"
	if [ ! -d "${nvm_home}" ]; then
		$sh_c_local "mkdir ${nvm_home}"
		$sh_c_local "wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | NVM_DIR=${nvm_home} PROFILE=${HOME}/.config/zsh/.zshrc /bin/bash"
	fi

	# mambaforge
	mambaforge_home="${HOME}/.local/share/mambaforge"
	if [ ! -d "${mambaforge_home}" ]; then
		$sh_c_local "wget -N -P /tmp/ https://github.com/conda-forge/miniforge/releases/latest/download/Mambaforge-$(uname)-$(uname -m).sh"
		$sh_c_local "bash /tmp/Mambaforge-$(uname)-$(uname -m).sh -bfs -p ${mambaforge_home}"
		$sh_c_local "rm /tmp/Mambaforge-$(uname)-$(uname -m).sh"
	fi

	exit 0
}

# wrapped up in a function so that we have some protection against only getting
# half the file during "curl | sh"
do_install
