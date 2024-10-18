# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# --------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------ My Def ------------------------------------------------------
# --------------------------------------------------------------------------------------------------------------------

export DAT="/mnt/Storage/Desktop/OSReset/dat";

export STORAGE="/mnt/Storage";

export MASTER="/mnt/Master";
export NOVEL="/mnt/Novel";
export BACKUP="/mnt/Backup";

export V_MASTER="/mnt/V-Master";
export V_NOVEL="/mnt/V-Novel";
export V_BACKUP="/mnt/V-Backup";

function closing() {

    function trapper() {
        while true; do
            read -r -p "Type 'Close' to exit: " input
            if [ "$input" = "Close" ]; then
                break;
            else
                echo "Invalid input. Please type 'Close' to exit.";
            fi
        done
    }

    if echo "$BASH_COMMAND" | grep -qE 'exit|INT|TERM'; then
        trapper; exec bash;
    else 
        echo "----------------------------------------";
        echo ""; echo "";
    fi

}

function copy_dir() {

    trap closing INT TERM EXIT;

    local SRC="$1";
    local DST="$2";

    if [ ! -d "$SRC" ]; then
        echo "Source: $SRC does not exist. Exiting."; exit 1;
    fi

    if [ ! -d "$DST" ]; then
        echo "Creating destination: $DST";
        if ! mkdir -p "$DST"; then
            echo "Failed to create destination: $DST. Exiting."; exit 1;
        else 
            echo "Destination: $DST has been created.";
        fi
    fi

    if ! cp -rv -p "$SRC"/. "$DST"; then
        echo "Failed to copy the files from $SRC to $DST. Exiting."; exit 1;
    else 
        echo "Files have been copied from $SRC to $DST.";
    fi
}

function remove_files() {

    trap closing INT TERM EXIT;

    if [ $# -eq 0 ]; then
        echo "No files to remove specified. Exiting."; exit 1;
    fi

    for file in "$@"; do

        if [ ! -e "$file" ] && [ ! -L "$file" ]; then
            echo "$file does not exist. Skipping."; continue;
        fi

        if ! sudo rm -v "$file"; then
            echo "Failed to remove $file. Exiting."; exit 1;
        else 
            echo "$file has been removed.";
        fi
    done
}

function change_owner() {

    trap closing INT TERM EXIT;

    if [ $# -lt 2 ]; then 
        echo "Usage: change_owner <owner>:<group> <file1> [file2] ..."
        echo "Less than 2 arguments were given. Exiting."; exit 1; 
    fi


    local owner_group="$1"; local IFS; shift;

    if ! IFS=":" read -r user group <<< "$owner_group"; then echo "Failed to read the owner and group. Exiting."; exit 1; fi
    if ! id "$user" &>/dev/null; then echo "User $user does not exist. Exiting."; exit 1; fi
    if ! getent group "$group" &>/dev/null; then echo "Group $group does not exist. Exiting."; exit 1; fi

    for file in "$@"; do

        if [ ! -e "$file" ] && [ ! -L "$file" ]; then echo "$file does not exist. Skipping."; exit 1; fi

        # Check current owner and group
        local c_owner=$(stat -c '%U' "$file");
        local c_group=$(stat -c '%G' "$file");

        if [ "$c_owner" = "$user" ] && [ "$c_group" = "$group" ]; then
            echo "$file is already owned by $user:$group. Skipping."; continue;
        fi

        if ! sudo chown -v "$owner_group" "$file"; then
            echo "Failed to change ownership of $file. Exiting."; exit 1;
        else 
            echo "Ownership of $file has been changed to $owner_group.";
        fi
    done

}

function install_flatpak() {

    trap closing INT TERM EXIT;
    
    if [ $# -eq 0 ]; then
        echo "No Flatpak specified. Exiting."; return 1;
    fi

    for pkg in "$@"; do

        if flatpak list | grep -q "$pkg"; then
            echo "$pkg is already installed."; continue;
        fi

        if ! flatpak install --assumeyes flathub "$pkg"; then
            echo "Failed to install $pkg. Exiting."; exit 1;
        else
            echo "$pkg has been installed successfully.";
        fi
    done
}

function list_deb() {

    ls "../3OS/Linux/Apps";

}

function install_dpkg() {

    trap closing INT TERM EXIT RETURN;

    if [ $# -eq 0 ]; then echo "No package specified. Exiting."; exit 1; fi

    local apps="/mnt/Storage/Desktop/OSReset/dat/Linux/Apps";

    for pkg in "$@"; do

        local path="$apps/$pkg";
        local name=$(basename "$pkg" .deb);

        if ! [ -e "$path" ]; then echo "$pkg does not exist. Exiting."; exit 1; fi

        # -i: Install the package.
        # -E: Skip packages whose same version is installed.
        # -G: Skip packages with earlier version than installed.
        
        if ! sudo dpkg -i -E -G "$path"; then

            # Fix broken updates
            if ! sudo dpkg --configure -a; then
                echo "Failed to configure packages"; exit 1;
            fi

            # Attempt to fix any broken dependencies
            if ! sudo apt-get --fix-broken install -y; then
                echo "Failed to fix broken dependencies."; exit 1;
            fi

            # Retry installing the package
            if ! sudo dpkg -i -E -G "$path"; then
                echo "Failed to install $pkg. Exiting."; exit 1;
            fi

        fi

    done

}

function install_apt() {

    trap closing INT TERM EXIT;

    if [ $# -eq 0 ]; then echo "No package specified. Exiting."; exit 1; fi

    sudo apt-get update; # Update the package lists

    for pkg in "$@"; do
    
        if ! dpkg -s "$pkg" &> /dev/null; then

            if ! sudo apt-get install "$pkg" -y; then

                # Update the package lists
                if ! sudo apt-get update; then
                    echo "Failed to update package lists"; exit 1;
                fi

                # Fix broken updates
                if ! sudo dpkg --configure -a; then
                    echo "Failed to configure packages"; exit 1;
                fi

                # Attempt to fix any broken dependencies
                if ! sudo apt-get --fix-broken install -y; then
                    echo "Failed to fix broken dependencies."; exit 1;
                fi

                # Retry installing the package
                if ! sudo apt-get install "$pkg" -y; then
                    echo "Failed to install $pkg. Exiting."; exit 1;
                fi

            fi

            echo "$pkg has been successfully installed.";

        else 
            echo "$pkg is already installed."
        fi
    done
}

function add_gpg() {

    # Expects input in the form of "URL1 keyring_name1.gpg" "URL2 keyring_name2.gpg" ...
    # Packages signed by keys needed to be pointed correctly to /etc/apt/keyrings when 
    # using this function.

    trap closing INT TERM EXIT;

    if [ $# -eq 0 ]; then echo "No keys were specified. Exiting."; exit 1; fi

    if [ ! -d "/etc/apt/keyrings" ]; then sudo mkdir -p "/etc/apt/keyrings"; fi

    for arg in "$@"; do

        read -r address keyring <<< "$arg";

        if [ -z "$address" ] || [ -z "$keyring" ]; then echo "Invalid argument: $arg"; exit 1; fi

        if [ -e "/etc/apt/keyrings/$keyring" ]; then echo "$keyring already exists. Skipping."; continue; fi

        # Download and dearmor the key, writing the output to a temporary file
        if ! curl -fsSL "$address" | gpg --dearmor -o "$keyring"; then
            echo "Failed to download and dearmor $keyring. Exiting."; 
            rm -f "$keyring"; exit 1;
        else 
            echo "$keyring has been added successfully.";
        fi

        # Install the key with correct permissions and ownership
        if ! sudo install -D -o root -g root -m 644 "$keyring" "/etc/apt/keyrings/$keyring"; then
            echo "Failed to install $keyring. Exiting."; rm -f "$keyring"; exit 1;
        else 
            rm -f "$keyring"; echo "$keyring has been added successfully.";
        fi

    done

}

function updatefix() {

    trap closing INT TERM EXIT;

    # Update the package lists
    if ! sudo apt update; then echo "Failed to update package lists"; exit 1; fi

    echo "Package lists updated successfully."

    # Fix broken updates
    if ! sudo dpkg --configure -a; then echo "Failed to configure packages"; exit 1; fi

    echo "Packages configured successfully."

    # Attempt to fix any broken dependencies
    if ! sudo apt --fix-broken install -y; then echo "Failed to fix broken dependencies."; exit 1; fi

    echo "Broken dependencies fixed successfully."

    # Install updates
    if ! sudo apt upgrade -y; then echo "Failed to install updates"; exit 1; fi

    echo "Updates installed successfully."

    # Remove unnecessary packages
    if ! sudo apt autoremove -y; then echo "Failed to remove unnecessary packages"; exit 1; fi

    echo "Unnecessary packages removed successfully."

    # Clean up the package cache
    if ! sudo apt clean; then echo "Failed to clean up the package cache"; exit 1; fi

    echo "Package cache cleaned successfully."

    echo "System updated and broken packages fixed successfully."
    
}

function install_signal() {

    trap closing INT TERM EXIT;

    if ! command -v "$signal" &> /dev/null; then

        add_gpg "https://updates.signal.org/desktop/apt/keys.asc signal-desktop-keyring.gpg";

        # Signal Repository
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/signal-desktop-keyring.gpg] \
        https://updates.signal.org/desktop/apt xenial main" | sudo tee /etc/apt/sources.list.d/signal-xenial.list;

        install_apt "signal-desktop";

    fi

}

function install_nordvpn() {

    if ! command -v nordvpn &> /dev/null; then

        sh <(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh);

        sudo groupadd nordvpn;
        sudo usermod -aG nordvpn "$USER";

    fi

    nordvpn set autoconnect on;
    nordvpn set killswitch on;
    nordvpn set threatprotectionlite on;
    nordvpn set notify on;
    nordvpn set lan-discovery enable;

}

function install_rust() {

    if ! command -v rustc &> /dev/null; then

        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y #Installs Rust

        # Update .bashrc if the Cargo environment setup isn't already included
        if ! grep -q ".cargo/env" ~/.bashrc; then
            echo ". \"$HOME/.cargo/env\"" >> ~/.bashrc
            source "$HOME/.cargo/env" # Source rust if needed right away in the script
        fi
        
    fi
}

function install_R() {

    trap closing INT TERM EXIT;

    echo "WARNING: This script will not work when run from within Cryptomator folder.";

    local Packages=(
        "languageserver"
        "rmarkdown"
        "ggplot2"
        "cowplot"
        "effects"
        "dplyr"
        "readxl"
        "broom"
        "mgcv"
        "faraway"
        "GGally"
    )

    updatefix; install_apt "r-base"; Packages+=("$@"); # Append additional packages to the list

    for pkg in "${Packages[@]}"; do

        if sudo R --slave -e "repos <- c(CRAN='https://cran.csiro.au'); if (!(\"$pkg\" %in% rownames(available.packages(repos=repos)))) quit(status=1)"; then

            if sudo R --slave -e "if (!require('$pkg', quietly = TRUE)) quit(status=1)"; then
                echo "$pkg is already installed.";
            else
                R --slave -e "install.packages('$pkg', repos='https://cran.csiro.au')";
                echo "$pkg has been installed successfully.";
            fi

        else 
            echo "$pkg is not available on the CRAN repository. Skipping.";
        fi

    done
    
}

function install_javascript() {

    trap closing INT TERM EXIT;

    local Packages=(
        "npm"
        "express"
        "puppeteer"
        "axios"
        "cheerio"
    )

    install_apt "npm";

    if ! command -v nvm &> /dev/null; then

        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash;

        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm

        if ! command -v nvm &> /dev/null; then
            echo "Failed to install nvm. Exiting."; exit 1;
        else 
            echo "nvm has been installed successfully.";
            nvm install --lts; nvm use --lts;
        fi
    fi

    echo "Using Node.js version: $(node -v)";
    echo "Using npm version: $(npm -v)";

    for pkg in "${Packages[@]}"; do

        if ! npm show "$pkg" &> /dev/null; then
            echo "Installing $pkg...";
            if ! npm install "$pkg"; then
                echo "Failed to install $pkg. Exiting."; exit 1;
            fi
        else
            echo "$pkg is already installed.";
        fi
    done

    echo "Installation complete. Installed packages:";
    npm list -g --depth=0;

}

function install_py() {

    trap closing INT TERM EXIT;

    # Verify conda installation
    if ! command -v conda &>/dev/null; then
        # Download and install Miniconda
        mkdir -p ~/miniconda3;
        wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh;
        bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3;
        rm -rf ~/miniconda3/miniconda.sh;

        # Initalise conda
        ~/miniconda3/bin/conda init bash;
    fi 

    # Verify pip installation
    if ! command -v pip &> /dev/null; then
        if ! conda install -y pip; then
            echo "Failed to install pip."; exit 1;
        fi
    fi 

}

function run_py() {

    trap closing INT TERM EXIT;

    local ENV="$1"; shift;
    local FILE="$1"; shift;

    echo "Usage: run_py <environment> <script> [packages]";

    if [ -z "$ENV" ]; then echo "No environment specified. Exiting."; return 1; fi

    if [ -e "$ENV" ]; then 
    
        echo "You forgot to put in Conda Environemnt."; 
        echo "$ENV was found inside the environment.";
        return 1; 
        
    fi

    if [ -z "$FILE" ]; then echo "No Python script specified. Exiting."; return 1; fi

    if [ ! -e "$FILE" ]; then echo "Python script not found. Exiting."; return 1; fi

    install_py; # Install Conda and pip if not already installed

    # Check if the Conda environment exists and create it if it does not
    if ! conda env list | grep -w "$ENV" &>/dev/null; then
        echo "Creating environment $ENV.";
        conda create -n "$ENV" python=3.10 -y;
    fi

    # Activate the environment
    echo "Activating environment '$ENV'.";
    source activate "$ENV";

    if [ ! $# -eq 0 ]; then

        echo "Installing packages in environment '$ENV'.";

        for pkg in "$@"; do

            if ! pip show "$pkg" &>/dev/null; then
                echo "Installing $pkg";
                pip install "$pkg" --quiet;
            fi

        done

    fi

    # Run the Python script
    echo "Running Python script '$FILE'.";
    python "$FILE";

    echo "Packages installed successfully.";
    echo "Deactivating environment '$ENV'.";
    conda deactivate;

}

function git_commit() {

    local MSG="$1"; shift;

    if [ -z "$MSG" ]; then echo "No commit message specified. Exiting."; return 1; fi

    git add .; git commit -m "$MSG"; git push origin main;

}

function convert_to_mp4() {

    trap closing INT TERM EXIT;

    # sudo -v; # Require the script to be run with sudo

    install_apt "ffmpeg"; # Install FFmpeg if not already installed

    rflag="false";

    if [ "$1" = "-r" ]; then rflag="true"; shift; fi

    list=$(if [ "$1" = "*" ]; then echo *; else echo "$@"; fi)

    for file in $list; do

        if [ -d "$file" ]; then continue; fi

        if [ ! -e "$file" ]; then echo "$file does not exist. Skipping."; continue; fi

        dir=$(dirname "$file")
        name=$(basename "$file" | sed 's/\.[^.]*$//')  # Strip any extension

        if [ -e "$dir/$name.mp4" ]; then echo "$dir/$name.mp4 already exists. Skipping."; continue; fi

        if ! ffmpeg -i "$file" \
            -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" \
            -c:v libx264 -crf 18 \
            -c:a aac -b:a 192k \
            -preset slow \
            -profile:v high \
            -level 4.0 \
            -pix_fmt yuv420p \
            "$dir/$name.mp4"; then

            if ! rm -v "$dir/$name.mp4"; then
                echo "Failed to remove $dir/$name.mp4. Exiting."; exit 1;
            fi

            echo "Failed to convert $file to MP4. Skipping."; continue;

        fi

        echo "Successfully converted $file to $dir/$name.mp4."

        if [ "$rflag" = "true" ]; then rm -v "$file"; fi

    done

}

# --------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------- Setup ------------------------------------------------------
# --------------------------------------------------------------------------------------------------------------------

function get_usb() {

    local serial="010129449371915a95ad4df62be4c0d466987bc29b5e7dbfa1e7aad6f435ab858806000000000000000000006a8d694e00867500ab5581076a2c7e8e";

    # Use globbing to match the serial number in the filenames
    local device_link="$(ls /dev/disk/by-id/*"$serial"* 2>/dev/null | head -n 1)";

    # If device not found return early
    if [ -z "$device_link" ]; then echo "USB device not found"; return 1; fi

    local partition_1="$(readlink -f $device_link)1";

    if [ ! -b "$partition_1" ]; then echo "USB partition not found"; return 1; fi

    gio mount -d "$partition_1" 2>/dev/null;

    local label=$(lsblk -no LABEL "$partition_1");
    local mount="/media/$USER/$label";

    if [ ! -d "$mount" ]; then echo "Failed to mount USB"; return 1; fi

    echo "$mount";
    
}

function copy_prefs() {

    trap closing INT TERM EXIT;

    if [ ! -d "$DAT" ]; then echo "Failed to locate the OSReset/dat directory."; exit 1; fi

    local clone="$DAT/Linux/$USER";
    local usb=$(get_usb);

    if [ -d "$usb" ]; then

        if ! rsync -rltDvh --delete "$clone" "$usb"/; then
            echo "Failed to copy over configuration files into USB."; exit 1;
        else 
            echo ""; echo "USB update successful!"; echo "";
        fi

        gio mount -u "$usb";

    fi 

    if ! rsync -avh "$clone"/ "$HOME"/; then 
        echo "Failed to copy over configuration files."; exit 1;
    else 
        echo ""; echo "Success! Closing to update terminal."; echo ""; exit 0;
    fi

}

function core_setup() {

    trap closing INT TERM EXIT;

    if [ ! -d "$STORAGE" ]; then
        install_signal; printf "\n\n";
        echo "Failed to locate the Master directory."; 
        echo "Use Signal to unlock your lux drives first."; exit 1;
    fi

    # ---------------------------------------------------------------------------------------------------------------------
    # -------------------------------------------------------- GRUB -------------------------------------------------------
    # ---------------------------------------------------------------------------------------------------------------------

    # Update GRUB Settings
    sudo sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=90/' /etc/default/grub;
    sudo sed -i 's/GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub;
    sudo update-grub;

    # ---------------------------------------------------------------------------------------------------------------------
    # ------------------------------------------------- Update APT Mirrors ------------------------------------------------
    # ---------------------------------------------------------------------------------------------------------------------

    local list="/etc/apt/sources.list.d/official-package-repositories.list";

    sudo sed -i 's|http://packages.linuxmint.com|https://mirror.aarnet.edu.au/pub/linuxmint-packages|g' "$list";
    sudo sed -i 's|http://archive.ubuntu.com/ubuntu|http://mirror.aarnet.edu.au/pub/ubuntu/archive|g' "$list";
    sudo apt update;

    # ---------------------------------------------------------------------------------------------------------------------
    # ------------------------------------------------------ Settings -----------------------------------------------------
    # ---------------------------------------------------------------------------------------------------------------------

    # Nemo - List View
    gsettings set org.nemo.list-view default-visible-columns "['name', 'size', 'type', 'date_modified', 'date_created']"; # Add the "Date Created" column to the list view

    # Nemo - Preferences
    gsettings set org.nemo.preferences enable-delete false; # Disable the delete command that bypasses the trash
    gsettings set org.nemo.preferences show-open-in-terminal-toolbar true; # Show "Open in Terminal" option in the context menu
    gsettings set org.nemo.preferences executable-text-activation 'ask'; # View executable text files when opened
    gsettings set org.nemo.preferences close-device-view-on-device-eject true; # Automatically close the device's tabs when the device is unmounted or ejected
    gsettings set org.nemo.preferences.menu-config selection-menu-move-to true; # Add "Move to" to the visible entries in the context menu
    gsettings set org.nemo.preferences tooltips-show-birth-date true; # Show the birth date in the tooltips
    gsettings set org.nemo.window-state network-expanded false; # Network is not expanded by default
    gsettings set org.nemo.window-state devices-expanded false; # Devices are not expanded by default

    # Cinnamon - All
    gsettings set org.cinnamon.desktop.media-handling automount false; # Disable automounting of media
    gsettings set org.cinnamon.desktop.interface gtk-theme 'Mint-Y-Dark-Aqua'; # Set the GTK theme to Dark
    gsettings set org.cinnamon.desktop.session idle-delay 0; # Set the idle delay to never
    gsettings set org.cinnamon.desktop.screensaver lock-delay 0; # Set the lock delay to immediately

    # Cinnamon - Laptop

    gsettings set org.cinnamon.settings-daemon.plugins.power sleep-display-ac 0; # Set the display sleep timeout to never on AC
    gsettings set org.cinnamon.settings-daemon.plugins.power sleep-display-battery 0 # Set the display sleep timeout to 30 minutes on battery

    gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-ac-timeout 0; # Set the sleep timeout to never
    gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-battery-timeout 1800; # Set the sleep timeout to 30 minutes

    gsettings set org.cinnamon.settings-daemon.plugins.power lid-close-ac-action 'shutdown'; # Shutdown when the lid is closed on AC
    gsettings set org.cinnamon.settings-daemon.plugins.power lid-close-battery-action 'shutdown'; # Shutdown when the lid is closed on battery

    # X - Editor
    gsettings set org.x.editor.preferences.editor prefer-dark-theme true; # Use dark theme for text editors

    # Set VLC as the default media player
    xdg-mime default vlc.desktop audio/mpeg audio/x-mpeg audio/ogg audio/x-vorbis+ogg audio/wav audio/x-wav audio/x-m4a \
    audio/mp4 video/mp4 video/x-msvideo video/mpeg video/ogg video/webm video/x-matroska video/x-flv application/ogg;

    # ---------------------------------------------------------------------------------------------------------------------
    # ------------------------------------------------------ Folders ------------------------------------------------------
    # ---------------------------------------------------------------------------------------------------------------------

    # Update user directories
    xdg-user-dirs-update --set DESKTOP "$STORAGE/Desktop";
    xdg-user-dirs-update --set DOWNLOAD "$STORAGE/Downloads";
    xdg-user-dirs-update --set PICTURES "$MASTER/Pictures";
    xdg-user-dirs-update --set VIDEOS "$MASTER/Videos";
    xdg-user-dirs-update --set MUSIC "$MASTER/Music";
    xdg-user-dirs-update --set DOCUMENTS "$MASTER/Documents";

    # Move original directories to trash
    if [ -d "$HOME/Desktop" ]; then gio trash "$HOME/Desktop"; fi
    if [ -d "$HOME/Downloads" ]; then gio trash "$HOME/Downloads"; fi
    if [ -d "$HOME/Pictures" ]; then gio trash "$HOME/Pictures"; fi
    if [ -d "$HOME/Videos" ]; then gio trash "$HOME/Videos"; fi
    if [ -d "$HOME/Music" ]; then gio trash "$HOME/Music"; fi
    if [ -d "$HOME/Documents" ]; then gio trash "$HOME/Documents"; fi
    if [ -d "$HOME/Public" ]; then gio trash "$HOME/Public"; fi
    if [ -d "$HOME/Templates" ]; then gio trash "$HOME/Templates"; fi

    if [ ! -d "$MASTER" ] && [ ! -d "$NOVEL" ] && [ ! -d "$BACKUP" ]; then
        sudo mkdir -p "$MASTER" "$V_MASTER" "$NOVEL" "$V_NOVEL" "$BACKUP" "$V_BACKUP"; # Create mount points
        change_owner "$USER":"$USER" "$MASTER" "$V_MASTER" "$NOVEL" "$V_NOVEL" "$BACKUP" "$V_BACKUP"; # Change ownership to user. (Otherwise, Cryptomator will crash)
    fi

    # ---------------------------------------------------------------------------------------------------------------------
    # --------------------------------------------------- Purge Firefox ---------------------------------------------------
    # ---------------------------------------------------------------------------------------------------------------------

    # Remove Firefox if installed as a system package
    if dpkg -l | grep -q firefox; then
        sudo apt-get purge firefox -y
        sudo apt-get autoremove
        sudo apt-get clean
        rm -rf ~/.mozilla
        rm -rf ~/.cache/mozilla/firefox/
        sudo apt-mark hold firefox #Prevent Firefox from being reinstalled
        echo "Firefox has been purged, related files removed, and the package is now held."
    fi

    # ---------------------------------------------------------------------------------------------------------------------
    # ---------------------------------------------------- Add KeyRings ---------------------------------------------------
    # ---------------------------------------------------------------------------------------------------------------------

    add_gpg \
    "https://packages.microsoft.com/keys/microsoft.asc packages.microsoft.gpg" \
    "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg brave-browser-archive-keyring.gpg" \
    "https://syncthing.net/release-key.gpg syncthing-archive-keyring.gpg";

    # ---------------------------------------------------------------------------------------------------------------------
    # -------------------------------------------------------- APT --------------------------------------------------------
    # ---------------------------------------------------------------------------------------------------------------------

    updatefix; install_apt wget gpg curl software-properties-common apt-transport-https shellcheck \
    flatpak libapr1 libaprutil1 libxml2-dev clinfo cmake vlc build-essential fonts-firacode \
    libsecret-tools;

    sudo add-apt-repository -y ppa:yubico/stable; # Add the YubiKey repository

    # VSCode Repository
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] \
    https://packages.microsoft.com/repos/vscode stable main" | sudo tee /etc/apt/sources.list.d/vscode.list;

    # Edge Repository
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] \
    https://packages.microsoft.com/repos/edge stable main" | sudo tee /etc/apt/sources.list.d/edge.list;

    # Brave Repository
    echo "deb [signed-by=/etc/apt/keyrings/brave-browser-archive-keyring.gpg] \
    https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list;

    # Syncthing Repository
    echo "deb [signed-by=/etc/apt/keyrings/syncthing-archive-keyring.gpg] \
    https://apt.syncthing.net/ syncthing stable" | sudo tee /etc/apt/sources.list.d/syncthing.list;

    # Pinning Syncthing Packages
    printf "Package: *\nPin: origin apt.syncthing.net\nPin-Priority: 990\n" | sudo tee /etc/apt/preferences.d/syncthing.pref;

    # ---------------------------------------------------------------------------------------------------------------------
    # ----------------------------------------------------- Basic Apps ----------------------------------------------------
    # ---------------------------------------------------------------------------------------------------------------------

    install_signal; install_apt "code" "brave-browser" "yubikey-manager-qt" "yubioath-desktop" "syncthing";
    
    # Set default browser to Brave
    xdg-settings set default-web-browser "brave-browser";

    install_flatpak "org.cryptomator.Cryptomator"; # Install Cryptomator

    sudo flatpak override org.cryptomator.Cryptomator --filesystem="$STORAGE/Cryptomator"; # Give Cryptomator access to Storage
    sudo flatpak override org.cryptomator.Cryptomator --filesystem="/mnt"; # Give Cryptomator access to Mount Points

    # ---------------------------------------------------------------------------------------------------------------------
    # ------------------------------------------------------- Clean Up ----------------------------------------------------
    # ---------------------------------------------------------------------------------------------------------------------

    updatefix; sudo reboot;

}

function setup_user() {

    trap closing INT TERM EXIT;

    if [ ! -d "$DAT" ]; then echo "Failed to locate the OSReset/dat directory."; exit 1; fi

    local auto_start="$DAT/Linux/AutoStart";

    install_rust; install_py;

    install_dpkg "Kuro.deb" "Discord.deb" "Outlook.deb";

    install_apt fonts-dejavu dropbox kalarm xournal default-jdk texlive-full \
    pandoc gimp git-all android-sdk-platform-tools microsoft-edge-stable;

    install_flatpak "com.rtosta.zapzap";

    # Copy user Autostart files
    copy_dir "$auto_start" "$HOME/.config/autostart";

}

function help() {

    echo "";
    echo "Available functions:";
    echo "closing - Exit the script after user confirmation.";
    echo "copy_dir - Copy files from source to destination.";
    echo "remove_files - Remove files from the system.";
    echo "install_flatpak - Install Flatpak packages.";
    echo "list_deb - List Debian packages.";
    echo "install_dpkg - Install Debian packages.";
    echo "install_apt - Install APT packages.";
    echo "updatefix - Update and fix broken packages.";
    echo "install_signal - Install Signal.";
    echo "install_nordvpn - Install NordVPN.";
    echo "install_rust - Install Rust.";
    echo "install_R - Install R packages.";
    echo "install_javascript - Install JavaScript packages.";
    echo "run_py - Run Python scripts in a Conda environment. Usage: run_py <environment> <script> [packages]";
    echo "git_login - Set Git user details.";
    echo "git_commit - Commit changes to Git repository.";
    echo "convert_to_mp4 - Convert video files to MP4 format.";
    echo "copy_prefs - Copy preferences to the user directory.";
    echo "core_setup - Setup core system settings.";
    echo "setup_user - Setup user environment.";
    echo "help - Display this help message.";
    echo "";

}

# Export common functions for use in subshells
export -f closing copy_dir change_owner remove_files install_flatpak install_dpkg \
install_apt updatefix convert_to_mp4 run_py git_login git_commit add_gpg;

# Export application installation functions for use in subshells
export -f install_nordvpn install_rust install_R install_javascript install_py;

# Export setup functions for use in subshells
export -f get_usb copy_prefs core_setup setup_user help;

echo "Welcome to the Linux environment. Type 'help' to see available functions.";

# --------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------ My Def ------------------------------------------------------
# --------------------------------------------------------------------------------------------------------------------

if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env";  # Source Rust environment
fi

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/dsinrust/miniconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/dsinrust/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/dsinrust/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/dsinrust/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

export NVM_DIR="$HOME/.nvm";
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh";  # This loads nvm