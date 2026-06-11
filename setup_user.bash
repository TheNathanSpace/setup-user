#!/usr/bin/env bash

export BLUE='\033[0;34m'    # Info
export GREEN='\033[0;32m'   # Action required
export YELLOW='\033[0;33m'  # Warning
export RED='\033[0;31m'     # Error
export NC='\033[0m'         # No Color

if [ "$(id -u)" -ne 0 ]; then echo -e "${RED}Please run as root.${NC}" >&2; exit 1; fi

prompt_yes_no() {
    local question="$1"
    local variable_name="$2"
    local response

    echo -e "${GREEN}${question} (y/n): ${NC}"
    read -p "(y/n): " response </dev/tty

    if [[ "$response" == "y" || "$response" == "Y" ]]; then
        export "${variable_name}=true"
    else
        export "${variable_name}=false"
    fi
}

give_to_user() {
  local file="$1"
  sudo chown "$USERNAME" "$file"
  sudo chmod 644 "$file"
}

# Only change directory if script is being run from an actual file
PIPED=false
if [[ -f "$0" ]]; then
    SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    cd "$SCRIPT_DIR" || (echo -e "${RED}Could not cd to current directory: cd ${SCRIPT_DIR}${NC}" && exit 1)
    echo -e "${BLUE}Changed to script directory: ${SCRIPT_DIR}${NC}"
else
    PIPED=true
    echo -e "${BLUE}Script is piped - staying in current directory: $(pwd)${NC}"
fi

USER_CLONED=false
if [[ "${PIPED}" == "false" && -f ".gitignore" ]]; then
    echo -e "${GREEN}We're running from a file, and a .gitignore was detected in the same directory.${NC}"
    prompt_yes_no "Did you clone the https://github.com/TheNathanSpace/setup-user repository?" USER_CLONED
    echo -e "${RED}Please clone the repo and run via that.${NC}"
    echo -e "${RED}Or, ensure you're running in a directory without a .gitignore, and that /home/<user>/setup-user/ is not used.${NC}"
    exit 1
else
    echo -e "${BLUE}We're running piped to Bash. We'll clone the https://github.com/TheNathanSpace/setup-user repo and then clean it up at the end. ${NC}"
fi

USERNAME=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --username)
            USERNAME="$2"
            shift 2
            ;;
        *)
            echo -e "${YELLOW}Unknown parameter: $1 ${NC}"
            ;;
    esac
done
if [[ -z "$USERNAME" ]]; then
    echo -e "${YELLOW}Warning: --username parameter not provided. Using 'nathan'.${NC}"
    USERNAME="nathan"
fi

echo -e "${BLUE}Here we go!${NC}"

prompt_yes_no "Do you want to create the user '$USERNAME'?" CREATE_USER
prompt_yes_no "Do you want to add all the Bash aliases?" ADD_BASH
prompt_yes_no "Do you want to install preferred programs?" INSTALL_PROGRAMS
prompt_yes_no "Do you want to install homelab programs?" INSTALL_HOMELAB
prompt_yes_no "Do you want to install Docker?" INSTALL_DOCKER
prompt_yes_no "Do you want to add NAS utilities?" ADD_NAS
prompt_yes_no "Do you want to copy gaming-laptop.local's SSH key to this machine?" ADD_PROXMOX_KEY

if [[ "${CREATE_USER}" == "true" ]]; then
  echo -e "${BLUE}Adding user $USERNAME and installing sudo...${NC}"
  id -u "$USERNAME" &>/dev/null || (useradd -m -d "/home/$USERNAME" "$USERNAME" && echo -e "${GREEN}You will be prompted for a new password for $USERNAME.${NC}" && passwd "$USERNAME") && (groupadd sudo; usermod -aG sudo "$USERNAME")
fi

if [[ "${USER_CLONED}" == "false" ]]; then
  echo -e "${BLUE}Cloning https://github.com/TheNathanSpace/setup-user to /home/${USERNAME}/setup-user/${NC}"
  bash -c "cd /home/${USERNAME} && git clone https://github.com/TheNathanSpace/setup-user"
  if ! cd "/home/${USERNAME}/setup-user/"; then
      echo -e "${RED}Could not cd to cloned repo: /home/${USERNAME}/setup-user/${NC}"
      exit 1
  fi
fi

if [[ "${INSTALL_PROGRAMS}" == "true" ]]; then
  echo -e "${BLUE}Installing other programs...${NC}"
  apt update
  apt upgrade -y
  apt install -y sudo vim curl git ack tree jq rsync python3 pipx python3-pip python-is-python3 zip unzip
  # Install yq prettier - https://github.com/mikefarah/yq
  sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq && sudo chmod +x /usr/local/bin/yq

  pipx install Pygments

  git config --global --type bool push.autoSetupRemote true
  git config --global credential.helper store
  git config --global core.editor "vim"
  git config --global user.name TheNathanSpace
  git config --global user.email 46632454+TheNathanSpace@users.noreply.github.com
fi

if [[ "${INSTALL_HOMELAB}" == "true" ]]; then
  echo -e "${BLUE}Installing homelab utilities...${NC}"
  sudo apt install -y openssh-server avahi-daemon avahi-utils sshfs qemu-guest-agent cifs-utils
fi

if [[ "${INSTALL_DOCKER}" == "true" ]]; then
  echo -e "${BLUE}Installing Docker...${NC}"
  sudo apt remove -y "$(dpkg --get-selections docker.io docker-compose docker-doc podman-docker containerd runc | cut -f1)"
  sudo apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
  sudo rm -rf /var/lib/docker
  sudo rm -rf /var/lib/containerd
  sudo rm /etc/apt/sources.list.d/docker.sources
  sudo rm /etc/apt/keyrings/docker.asc
  curl -fsSL https://get.docker.com -o get-docker.sh
  chmod +x get-docker.sh
  sudo sh get-docker.sh
  rm get-docker.sh
  sudo groupadd docker
  sudo usermod -aG docker "$USERNAME"
fi

mkdir "/home/$USERNAME/bin"
give_to_user "/home/$USERNAME/bin"

if [[ "${ADD_NAS}" == "true" ]]; then
  cp ".smbcredentials" "/home/$USERNAME/.smbcredentials"
  cp "mount-nas.bash.template" "/home/$USERNAME/bin/mount-nas.bash.template"
  cp "unmount-nas.bash.template" "/home/$USERNAME/bin/unmount-nas.bash.template"

  give_to_user "/home/$USERNAME/.smbcredentials"
  give_to_user "/home/$USERNAME/bin/mount-nas.bash.template"
  give_to_user "/home/$USERNAME/bin/unmount-nas.bash.template"

  chmod +x "/home/$USERNAME/bin/mount-nas.sh"
  chmod +x "/home/$USERNAME/bin/unmount-nas.sh"

  echo -e "${GREEN}You will want to change the NAS directories mounted in ~/bin/mount-nas.bash.template and ~/bin/unmount-nas.bash.template.${NC}"
fi

if [[ "${ADD_BASH}" == "true" ]]; then
  echo -e "${BLUE}Setting up Bash aliases...${NC}"

  touch "/home/$USERNAME/.bashrc"
  cat << 'BASHRC' >> "/home/$USERNAME/.bashrc"
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi
BASHRC

  cat .bash_aliases >> "/home/$USERNAME/.bash_aliases"
  cat .debian_bash >> "/home/$USERNAME/.debian_bash"
  cat .vimrc >> "/home/$USERNAME/.vimrc"

  give_to_user "/home/$USERNAME/.bashrc"
  give_to_user "/home/$USERNAME/.bash_aliases"
  give_to_user "/home/$USERNAME/.debian_bash"
  give_to_user "/home/$USERNAME/.vimrc"
fi

if [[ "${ADD_PROXMOX_KEY}" == "true" ]]; then
  echo -e "${BLUE}Copying SSH key from gaming-laptop.local to this machine...${NC}"
  echo -e "${GREEN}You will be prompted for nathan@gaming-laptop.local's password.${NC}"
  MACHINE_A_IP=$(hostname -I | awk '{print $1}')
  ssh -t root@gaming-laptop.local "ssh-copy-id nathan@${MACHINE_A_IP}"
  echo -e "${BLUE}SSH key copied${NC}"
fi

if [[ "${USER_CLONED}" == "false" ]]; then
  echo -e "${BLUE}Deleting /home/${USERNAME}/setup-user/${NC}"
  sudo rm -rf "/home/${USERNAME}/setup-user/"
fi

echo -e "${GREEN}All done! Run 'su $USERNAME' when ready.${NC}"

if [[ "${USER_CLONED}" == "true" ]]; then
  echo -e "${GREEN}Since you cloned the setup-user repo, you'll probably want to delete it: $(pwd)${NC}"
fi
