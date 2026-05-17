#!/bin/bash

export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

if [ "$(id -u)" -ne 0 ]; then echo "${RED}Please run as root.${NC}" >&2; exit 1; fi

echo -e "${YELLOW}Here we go!${NC}"

prompt_yes_no() {
    local question="$1"
    local variable_name="$2"
    local response

    echo -e "${YELLOW}${question} (y/n): ${NC}"
    read -p "(y/n): " response

    if [[ "$response" == "y" || "$response" == "Y" ]]; then
        export "${variable_name}=true"
    else
        export "${variable_name}=false"
    fi
}

give_to_nathan() {
  local file="$1"
  sudo chown nathan "$file"
  sudo chmod 644 "$file"
}

prompt_yes_no "Do you want to create the user 'nathan'?" CREATE_USER
prompt_yes_no "Do you want to add all the Bash aliases?" ADD_BASH
prompt_yes_no "Do you want to install preferred programs?" INSTALL_PROGRAMS
prompt_yes_no "Do you want to install homelab programs?" INSTALL_HOMELAB
prompt_yes_no "Do you want to install Docker?" INSTALL_DOCKER
prompt_yes_no "Do you want to add NAS utilities?" ADD_NAS
prompt_yes_no "Do you want to copy gaming-laptop.local's SSH key to this machine?" ADD_PROXMOX_KEY

if [[ "${CREATE_USER}" == "true" ]]; then
  echo -e "${YELLOW}Adding user nathan and installing sudo...${NC}"
  id -u nathan &>/dev/null || (useradd -m -d /home/nathan nathan && echo -e "\033[0;33mYou will be prompted for a new password for nathan.\033[0m" && passwd nathan) && (groupadd sudo; usermod -aG sudo nathan)
fi

if [[ "${INSTALL_PROGRAMS}" == "true" ]]; then
  echo -e "${YELLOW}Installing other programs...${NC}"
  apt update
  apt upgrade -y
  apt install -y sudo vim curl git ack tree jq rsync python3 pipx python3-pip python-is-python3
  # Install yq prettier - https://github.com/mikefarah/yq
  sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq && sudo chmod +x /usr/local/bin/yq

  git config --global --type bool push.autoSetupRemote true
  git config --global credential.helper store
  git config --global core.editor "vim"
fi

if [[ "${INSTALL_HOMELAB}" == "true" ]]; then
  echo -e "${YELLOW}Installing homelab utilities...${NC}"
  sudo apt install -y openssh-server avahi-daemon avahi-utils sshfs qemu-guest-agent cifs-utils
fi

if [[ "${INSTALL_DOCKER}" == "true" ]]; then
  echo -e "${YELLOW}Installing Docker...${NC}"
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
  sudo usermod -aG docker nathan
fi

mkdir /home/nathan/bin
give_to_nathan /home/nathan/bin

if [[ "${ADD_NAS}" == "true" ]]; then
  cat << 'SMBCREDS' >> /home/nathan/.smbcredentials
username=guest
password=:VFRB6~b
SMBCREDS

  cat << 'MOUNTNAS' >> /home/nathan/bin/mount-nas.sh
#!/bin/bash
sudo mount -t cifs //192.168.1.6/CHOOSE_SHARED_FOLDER /home/nathan/CHOOSE_MOUNT_LOCATION -o credentials=/home/nathan/.smbcredentials,uid=1000,gid=1000,vers=3.0
MOUNTNAS

  cat << 'UNMOUNTNAS' >> /home/nathan/bin/unmount-nas.sh
#!/bin/bash
sudo umount /home/nathan/CHOOSE_MOUNT_LOCATION
UNMOUNTNAS

  give_to_nathan /home/nathan/.smbcredentials
  give_to_nathan /home/nathan/bin/mount-nas.sh
  give_to_nathan /home/nathan/bin/unmount-nas.sh

  chmod +x /home/nathan/bin/mount-nas.sh
  chmod +x /home/nathan/bin/unmount-nas.sh

  echo -e "${YELLOW}You will want to change the NAS directories mounted in ~/bin/mount-nas.sh and ~/bin/unmount-nas.sh.${NC}"
fi

if [[ "${ADD_BASH}" == "true" ]]; then
  echo -e "${YELLOW}Setting up Bash aliases...${NC}"

  touch /home/nathan/.bashrc
  cat << 'BASHRC' >> /home/nathan/.bashrc
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi
BASHRC

  cat .bash_aliases >> /home/nathan/.bash_aliases
  cat .debian_bash >> /home/nathan/.debian_bash
  cat .vimrc >> /home/nathan/.vimrc

  give_to_nathan /home/nathan/.bashrc
  give_to_nathan /home/nathan/.bash_aliases
  give_to_nathan /home/nathan/.debian_bash
  give_to_nathan /home/nathan/.vimrc
fi

if [[ "${ADD_PROXMOX_KEY}" == "true" ]]; then
  echo -e "${YELLOW}Copying SSH key from gaming-laptop.local to this machine...${NC}"
  echo -e "${YELLOW}You will be prompted for nathan@gaming-laptop.local's password.${NC}"
  MACHINE_A_IP=$(hostname -I | awk '{print $1}')
  ssh -t root@gaming-laptop.local "ssh-copy-id nathan@${MACHINE_A_IP}"
  echo -e "${GREEN}SSH key copied${NC}"
fi

echo -e "${YELLOW}All done! Run 'su nathan' when ready.${NC}"
