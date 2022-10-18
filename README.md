# setup

1.  install git
    ```bash
    sudo apt install git
    ```
    
1.  make a new ssh key and add it to githubs
    ```bash
    ssh-keygen -t ed25519 -C "${EMAIL_ADDRESS}"
    cat ~/.ssh/id_ed25519.pub
    ```
    https://github.com/settings/keys
    
1.  clone this repository
    ```bash
    mkdir -p ~/Documents/mooyeolb
    cd ~/Documents/mooyeolb
    git clone git@github.com:mooyeolb/setup.git
    ```


