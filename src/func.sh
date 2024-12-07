#!/bin/bash

# <CSF-S>

function closing() {

    echo -e "Exiting script. Bash died.";

    while true; do
        read -r -p "Type 'Close' to exit: " input
        if [ "$input" = "Close" ]; then
            echo -e "\n"; exec bash;
        else
            echo "Invalid input. Please type 'Close' to exit.";
        fi
    done

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

function clear_duplicates() {

    local dir dupe orig dupe_ext orig_ext dupe_size orig_size;

    dir="$PWD";

    if [ ! -d "$dir" ]; then echo "Directory not found. Exiting. Dir: $dir"; return 1; fi

    find "$dir" -path "*/.Trash-1000" -prune -o -path "*/lost+found" -prune -o -type f -print | while read -r dupe; do

        if [ -f "$dupe" ]; then

            if [[ "$dupe" =~ [[:space:]]\([0-9]+\)\. ]] || [[ "$dupe" =~ [[:space:]]Copy\. ]] || [[ "$dupe" =~ [[:space:]]\(copy\)\. ]]; then

                orig="$(echo "$dupe" | sed -E 's/ \([0-9]+\)\././' | sed -E 's/ Copy\./\./' | sed -E 's/ \(copy\)\./\./')";

                # Check if original exists
                if [ ! -f "$orig" ]; then mv -v "$dupe" "$orig"; continue; fi

                # Check extensions match
                dupe_ext="${dupe##*.}"
                orig_ext="${orig##*.}"
                if [ "$dupe_ext" != "$orig_ext" ]; then continue; fi

                # Compare sizes
                dupe_size=$(stat -c %s "$dupe")
                orig_size=$(stat -c %s "$orig")
                if [ "$dupe_size" != "$orig_size" ]; then continue; fi

                # Compare actual content
                if ! cmp -s "$dupe" "$orig"; then continue; fi

                if [ -f "$orig" ]; then 
                    echo "Duplicate: $dupe";
                    echo "Original: $orig";
                    gio trash "$dupe"; 
                fi

            fi

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

function install_dpkg() {

    trap closing INT TERM EXIT RETURN;

    if [ $# -eq 0 ]; then echo "No package specified. Exiting."; exit 1; fi

    local apps="./dat/Linux/Apps";

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

function wonky_graphics() {

    sudo dpkg --add-architecture i386;
    install_apt libgl1:i386 libglx-mesa0:i386 libdrm2:i386 libx11-6:i386 libxext6:i386;
    sudo reboot;

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

        rustup target add x86_64-pc-windows-gnu; # Add Windows target
        
    fi
}

function discord() {

    install_dpkg Discord.deb; discord;

}

function install_R() {

    trap closing INT TERM EXIT;

    echo "WARNING: This script will not work when run from within Cryptomator folder.";

    # Get the R major and minor version dynamically
    local R_VERSION=$(R --slave -e 'cat(R.version$major, ".", strsplit(R.version$minor, "\\.")[[1]][1], sep="")');

    # Define the dynamic user library path
    local LIB="$HOME/R/x86_64-pc-linux-gnu-library/$R_VERSION";

    updatefix; install_apt "r-base"; mkdir -p "$LIB";

    R --slave -e "install.packages('languageserver', repos='https://cran.csiro.au', lib='$LIB')";
    
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

function store_public_key() {

    local key type id key_file timestamp;

    # Required parameters
    key="$1";                       # The actual public key content
    type="$2";                  # Type of key (e.g., yubikey, ssh, gpg)
    id="$3";               # Additional descriptive information
    
    # Ensure we have the required parameters
    if [ -z "$key" ] || [ -z "$type" ] || [ -z "$id" ]; then
        echo -e "Error: Missing required parameters.\n";
        if [ -f "$PK_README" ]; then cat "$PK_README"; else
            echo "Couldn't show README. Not found at $PK_README";
        fi
        return 1;
    fi

    # Generate a filename that includes all relevant information
    timestamp=$(date +%Y%m%d);
    key_file="${PUB_KEYS}/${type}_${id}_${timestamp}.pub";

    if ! echo "$key" > "$key_file"; then
        echo "Failed to save the public key to $key_file"; return 1;
    else 
        echo -e "\nPublic key saved to: $key_file"; return 0;
    fi
    
}

function setup_ssh() {

    echo "Checking SSH server status...";

    # Check if SSH server is installed
    if ! command -v sshd &>/dev/null; then

        echo "SSH server not found. Installing...";

        install_apt "openssh-server";

    fi

    # Check if SSH service is running
    if ! systemctl is-active --quiet ssh; then

        echo "Starting SSH service..."

        if ! sudo systemctl start ssh; then
            echo "Failed to start SSH service" >&2; return 1;
        fi

    fi

    # Enable SSH service on boot if not already enabled
    if ! systemctl is-enabled --quiet ssh; then

        echo "Enabling SSH service on boot..."

        if ! sudo systemctl enable ssh; then
            echo "Failed to enable SSH service" >&2; return 1;
        fi

    fi

    # Get network information
    local ip_address;
    ip_address=$(hostname -I | awk '{print $1}');
    
    # Display connection info
    echo -e "\nSSH server setup complete!";
    echo "Server IP address: ${ip_address}";
    echo "Default SSH port: 22";
    echo "Connection string: ssh ${USER}@${ip_address}";
    echo -e "\nTo connect from Windows:";
    echo "1. Open VSCode";
    echo "2. Press F1 and type 'Remote-SSH: Connect to Host'";
    echo "3. Enter: ${USER}@${ip_address}";

}

function launch_yubikey_ssh() {

    function relaunch() {
    
        echo "Attempting to restart GPG agent...";
        gpgconf --kill gpg-agent;
        gpgconf --launch gpg-agent;
        sleep 1; # Give the agent a moment to initialize
        gpg-connect-agent updatestartuptty /bye;
        if [ ! -S "$SSH_AUTH_SOCK" ]; then 
            echo "❌ GPG agent SSH support not properly configured"; return 1; 
        fi
    }

    echo "Initializing SSH and GPG configurations...";
    local gpg_agent_conf shell_rc auth_key ssh_key cardno;

    # Ensure GPG agent configuration exists and is correct
    gpg_agent_conf="$HOME/.gnupg/gpg-agent.conf";
    mkdir -p "$HOME/.gnupg"; chmod 700 "$HOME/.gnupg";

    # Update or add configurations
    grep -qxF 'enable-ssh-support' "$gpg_agent_conf" || echo 'enable-ssh-support' >> "$gpg_agent_conf";
    grep -qxF 'default-cache-ttl 60' "$gpg_agent_conf" || echo 'default-cache-ttl 60' >> "$gpg_agent_conf";
    grep -qxF 'max-cache-ttl 120' "$gpg_agent_conf" || echo 'max-cache-ttl 120' >> "$gpg_agent_conf";

    # Ensure SSH configuration is present in shell startup file
    case "$SHELL" in
        */bash) shell_rc="$HOME/.bashrc" ;;
        */zsh)  shell_rc="$HOME/.zshrc" ;;
        *)      shell_rc="$HOME/.profile" ;;
    esac

    echo "Checking GPG SSH environment configuration...";
    if ! grep -q "GPG_TTY" "$shell_rc"; then

        echo "Adding GPG SSH environment configuration to $shell_rc...";

        {
            echo ''
            echo '# Configure GPG SSH agent'
            echo 'export GPG_TTY=$(tty)'
            echo 'export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)'
            echo 'gpgconf --launch gpg-agent'
        } >> "$shell_rc";
    fi

    echo "Ensuring GPG SSH environment is properly configured...";
    export GPG_TTY=$(tty);
    export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket);
    gpgconf --launch gpg-agent;

    echo "Testing YubiKey SSH configuration...";

    # Step 1: Check if YubiKey is detected
    echo -e "\n1. Testing YubiKey detection...";
    if ! gpg --card-status &>/dev/null; then
        echo "❌ YubiKey not detected. Please insert your YubiKey and try again."; return 1;
    fi
    echo "✓ YubiKey detected";

    # Step 2: Check GPG keys on YubiKey
    echo -e "\n2. Checking GPG keys on YubiKey...";
    auth_key=$(gpg --with-colons --card-status | awk -F: '/^fpr:/ {print $4}' | tail -n1);

    if [ -z "$auth_key" ]; then
        echo "❌ No authentication key found on YubiKey.";
        echo "Please follow these steps to add an authentication key:";
        echo "1. Find your key ID with: gpg --list-secret-keys --keyid-format LONG";
        echo "2. Run: gpg --expert --edit-key YOUR_KEY_ID";
        echo "3. At the gpg> prompt, type: addkey";
        echo "4. Choose the appropriate key type (e.g., RSA, ECC)";
        echo "5. Set capabilities to authentication only";
        echo "6. Follow the prompts to generate the key";
        return 1;
    fi
    echo "✓ Authentication key found: $auth_key";

    # Step 3: Check GPG agent SSH support
    echo -e "\n3. Checking GPG agent SSH support...";
    relaunch; echo "✓ GPG agent SSH support available";    

    # Step 4: Test SSH key availability
    echo -e "\n4. Testing SSH key availability...";
    gpg-connect-agent updatestartuptty /bye;
    sleep 1; # Give the agent a moment to initialize

    # First check if we can get any keys
    ssh_key=$(ssh-add -L 2>/dev/null | grep "cardno");

    if [ -z "$ssh_key" ]; then
        relaunch; # Restart GPG agent and try again
        ssh_key=$(ssh-add -L 2>/dev/null | grep "cardno") # Try getting the key again
        if [ -z "$ssh_key" ]; then
            echo "❌ No SSH key available from YubiKey";
            echo "Debugging information:";
            echo "GPG Agent Socket: $(gpgconf --list-dirs agent-ssh-socket)";
            echo "SSH_AUTH_SOCK: $SSH_AUTH_SOCK"; return 1;
        fi
    fi
    echo "✓ SSH key available from YubiKey";

    # Provide the public key to the user
    echo -e "\nYour SSH public key (copy this to remote servers):";
    echo "$ssh_key";

    # Extract the card number for use as part of the description
    cardno=$(echo "$ssh_key" | grep -o "cardno:[0-9_]*" | sed 's/:/-/g');
    store_public_key "$ssh_key" "yubikey" "$cardno";

    echo -e "\n✓ YubiKey SSH configuration complete!";
    echo "You can now use your YubiKey for SSH authentication.";

}

function conda_run() {

    trap closing INT TERM EXIT;

    local ENV="$1"; shift;
    local FILE="$1"; shift;

    echo "Usage: conda_run <environment> <script> [packages]";

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

function insert_script() {

    trap closing INT TERM EXIT;

    local write_type input output insert;

    while [ "$1" != "" ]; do

        case "$1" in
            -a | -o) 
                if [ -z "$write_type" ]; then write_type="$1"; else 
                    echo "Error: Too many write types provided." >&2; exit 1;
                fi
            ;;
            *) 
                if [ -f "$1" ]; then

                    if [ -z "$input" ]; then input="$1";

                    elif [ -z "$output" ]; then output="$1"; else 
                        echo "Error: Too many files provided." >&2; exit 1;
                    fi

                fi
            ;;
        esac
        shift;
    done

    # Check if the write flag was provided
    if [ -z "$write_type" ]; then echo "Error: No valid write flag was provided. Use [-a, -o]" >&2; exit 1; fi

    # Check if the input file exists
    if [ ! -f "$input" ]; then echo "Error: No script source file was provided." >&2; exit 1; fi

    # Check if the output file exists
    if [ ! -f "$output" ]; then echo "Error: No output file provided." >&2; exit 1; fi

    local TAGS="# <CSF-S>"; # Custom Shell Function - Start Tag
    local TAGE="# <CSF-E>"; # Custom Shell Function - End Tag
    local output_ts output_te input_st input_et;

    # Search for the opening and closing CSF tags in input
    input_st=$(grep -n "^$TAGS$" "$input" | cut -d: -f1 | head -n1);
    input_et=$(grep -n "^$TAGE$" "$input" | cut -d: -f1 | tail -n1);

    # Search for the opening and closing CSF tags in output
    output_ts=$(grep -n "^$TAGS$" "$output" | cut -d: -f1 | head -n1);
    output_te=$(grep -n "^$TAGE$" "$output" | cut -d: -f1 | tail -n1);

    # Check for missing start tag in input
    if [ -z "$input_st" ]; then
        echo "Error: Missing start CSF tag in the input file." >&2; exit 1;
    fi

    # Check for missing end tag in input
    if [ -z "$input_et" ]; then
        echo "Error: Missing end CSF tag in the input file." >&2; exit 1;
    fi

    # Check if the tags are in the correct order in input
    if [ "$input_st" -ge "$input_et" ]; then
        echo "Error: Input file is corrupted. Tags are incorrectly ordered." >&2; exit 1;
    fi

    # Check for missing start tag in output
    if [ -n "$output_ts" ] && [ -z "$output_te" ]; then
        echo "Error: Output file is corrupted. End tag is missing." >&2; exit 1;
    fi
    
    # Check for missing end tag in output
    if [ -z "$output_ts" ] && [ -n "$output_te" ]; then
        echo "Error: Output file is corrupted. Start tag is missing." >&2; exit 1;
    fi

    # Check for both missing tags in output
    if [ -z "$output_ts" ] && [ -z "$output_te" ]; then

        # Append the CSF tags
        if ! echo -e "\n$TAGS\n$TAGE" >> "$output"; then
            echo "Error: Failed to append CSF tags to User .bashrc." >&2; exit 1;
        fi

        # Update output_ts and output_te after appending tags
        output_ts=$(grep -n "^$TAGS$" "$output" | cut -d: -f1 | head -n1)
        output_te=$(grep -n "^$TAGE$" "$output" | cut -d: -f1 | tail -n1)
        
    fi

    # Check if the tags are in the correct order in output
    if [ "$output_ts" -ge "$output_te" ]; then
        echo "Error: Output file is corrupted. Tags are incorrectly ordered." >&2; exit 1;
    fi

    # Both tags in the input and output exist and are correctly ordered

    middle=$(mktemp); bottom=$(mktemp); 

    # Backup the content between the tags from the output
    if ! sed -n "$((output_ts+1)),$((output_te-1))p" "$output" > "$middle"; then
        echo "Error: Failed to extract the content between the tags." >&2; exit 1;
    fi

    # Backup the content from the end tag to EOF
    if ! sed -n "$output_te,\$p" "$output" > "$bottom"; then
        echo "Error: Failed to extract the content after the end tag." >&2; exit 1;
    fi

    # Remove the existing content from (not including) the start tag to EOF
    if ! sed -i "$((output_ts+1)),\$d" "$output"; then
        echo "Error: Failed to remove the existing content below the start tag." >&2; return 1
    fi

    insert=$(sed -n "$((input_st+1)),$((input_et-1))p" "$input");

    if [ "$write_type" == "-a" ]; then echo "$insert" >> "$middle";

    elif [ "$write_type" == "-o" ]; then echo "$insert" > "$middle"; fi 

    # Insert the new content below the start tag
    if ! cat "$middle" >> "$output"; then
        echo "Error: Failed to insert the new content below the start tag." >&2; exit 1;
    fi

    # Append the backed up content after the new content
    if ! cat "$bottom" >> "$output"; then
        echo "Error: Failed to append the backed-up content." >&2; exit 1;
    fi

    # Clean up temporary files
    rm -f "$middle" "$bottom";

    echo "Bashrc has been updated successfully.";

}

function git_push() {

    if [ $# -eq 0 ]; then echo "No inputs. Usage: git_push <branch> <message>"; return 1;
    elif [ $# -ge 3 ]; then echo "Too many inputs. Usage: git_push <branch> <message>"; return 1; fi

    local branch msg;

    if [ $# -eq 2 ]; then branch="$1"; msg="$2"; else 
        msg="$1"; branch="$(git branch --show-current)";
    fi

    if ! git branch -r | grep -qE "origin/$branch$"; then
        echo "Remote branch: $branch does not exist. Exiting."; return 1;
    fi

    if [ "$branch" == "main" ]; then
        read -p "You are about to push to the remote main branch. Are you sure? (y/n): " confirm;
        if [ "$confirm" != "y" ]; then echo "Push to 'main' aborted."; return 1; fi;
    fi

    # -S: Signed commit
    git add .; git commit -S -m "$msg"; git push origin "$branch";

}

function nd_start() {

    local nd mdir model;
    nd="$HOME/.config/nerd-dictation";
    mdir="$nd/model";

    if [ ! -d "$nd" ]; then

        pip3 install vosk || { echo "Error: Failed to install vosk"; exit 1; }
        mkdir -p "$mdir";
        git clone https://github.com/ideasman42/nerd-dictation.git "$nd";

        echo "Nerd Dictation has been installed successfully."

    fi

    # Download small model if not present
    if [ ! -d "$mdir/small" ]; then
        wget https://alphacephei.com/kaldi/models/vosk-model-small-en-us-0.15.zip
        unzip vosk-model-small-en-us-0.15.zip
        mv vosk-model-small-en-us-0.15 "$mdir/small"

        echo "The small model has been installed successfully."
    fi

    # Download large model if not present
    if [ ! -d "$mdir/large" ]; then
        wget https://alphacephei.com/kaldi/models/vosk-model-en-us-0.22.zip
        unzip vosk-model-en-us-0.22.zip
        mv vosk-model-en-us-0.22 "$mdir/large"

        echo "The large model has been installed successfully."
    fi

    # Determine which model to use based on the -s argument
    if [ "$1" == "-s" ]; then
        model="$mdir/small"
    else
        model="$mdir/large"
    fi

    # Run nerd-dictation with the selected model
    "$nd/nerd-dictation" begin --vosk-model-dir="$model" &>/dev/null &

}

function nd_end() {

    "$HOME/.config/nerd-dictation/nerd-dictation" end;

}

function help() {

    # Header color, Highlight, Reset for output
    local HCLR="\033[1;34m" HSTL="\033[1m" HRST="\033[0m";

    case "$1" in
        -gen)
            echo -e "\n${HCLR}General Utilities:${HRST}"
            echo -e "${HSTL}closing${HRST} - Exit the script after user confirmation."
            echo -e "${HSTL}copy_dir${HRST} - Copy files from source to destination."
            echo -e "${HSTL}remove_files${HRST} - Remove files from the system."
            echo -e "${HSTL}list_deb${HRST} - List Debian packages."
            ;;

        -setup)
            echo -e "\n${HCLR}Preferences and Setup:${HRST}"
            echo -e "${HSTL}copy_prefs${HRST} - Copy preferences to the user directory."
            echo -e "${HSTL}core_setup${HRST} - Setup core system settings."
            echo -e "${HSTL}setup_user${HRST} - Setup user environment."
            ;;

        -install)
            echo -e "\n${HCLR}Installation and Updates:${HRST}"
            echo -e "${HSTL}install_flatpak${HRST} - Install Flatpak packages."
            echo -e "${HSTL}install_dpkg${HRST} - Install Debian packages."
            echo -e "${HSTL}install_apt${HRST} - Install APT packages."
            echo -e "${HSTL}updatefix${HRST} - Update and fix broken packages."
            echo -e "${HSTL}wonky_graphics${HRST} - Fix graphics issues by installing 32-bit libraries."
            echo -e "${HSTL}discord${HRST} - Install/Update Discord."
            ;;

        -net)
            echo -e "\n${HCLR}Networking and Communication:${HRST}"
            echo -e "${HSTL}setup_ssh${HRST} - Install and configure SSH server, displays connection info."
            echo -e "${HSTL}install_signal${HRST} - Install Signal."
            echo -e "${HSTL}install_nordvpn${HRST} - Install NordVPN."
            ;;

        -dev)
            echo -e "\n${HCLR}Development Tools:${HRST}"
            echo -e "${HSTL}install_rust${HRST} - Install Rust."
            echo -e "${HSTL}install_R${HRST} - Install R packages."
            echo -e "${HSTL}install_javascript${HRST} - Install JavaScript packages."
            echo -e "${HSTL}conda_run${HRST} - Run Python scripts in a Conda environment. Usage: conda_run <environment> <script> [packages]"
            ;;

        -media)
            echo -e "\n${HCLR}Media Tools:${HRST}"
            echo -e "${HSTL}convert_to_mp4${HRST} - Convert video files to MP4 format."
            ;;

        -nerd)
            echo -e "\n${HCLR}Nerd Dictation:${HRST}"
            echo -e "${HSTL}nd_start${HRST} - Start Nerd Dictation."
            echo -e "${HSTL}nd_end${HRST} - End Nerd Dictation."
            ;;

        -dict)
            echo -e "\n${HCLR}Command Dictionary:${HRST}"
            echo -e "${HSTL}gsettings list-recursively org.nemo${HRST} - Shows all available preferences for Nemo."
            echo -e "${HSTL}gsettings list-recursively | grep -i <keyword>${HRST} - Search for setting via keyword."
            echo -e "    ${HSTL}E.g.${HRST} gsettings list-recursively | grep -i \"theme\""
            echo -e "${HSTL}sudo dpkg --configure -a${HRST} - Fixes interrupted or broken package installations."
            echo -e "${HSTL}sudo apt update${HRST} - Updates package lists."
            echo -e "${HSTL}sudo apt upgrade${HRST} - Installs all updates from package lists."
            echo -e "${HSTL}sudo apt --fix-broken install${HRST} - Fixes dependencies for broken packages."
            
            echo -e "\n${HCLR}Flag Dictionary:${HRST}"
            echo -e "${HSTL}-y${HRST} - Automatically inputs 'Yes' for confirmation prompts."
            ;;

        -git)
            echo -e "\n${HCLR}Git Common Commands:${HRST}"
            echo -e "Initialize a new repository:                       ${HSTL}git init${HRST}"
            echo -e "Clone a repository:                                ${HSTL}git clone <url>${HRST}"
            echo -e "Create a new branch and switch to it:              ${HSTL}git checkout -b <branch>${HRST}"
            echo -e "Switch to an existing branch:                      ${HSTL}git checkout <branch>${HRST}"
            echo -e "List all local and remote branches:                ${HSTL}git branch -a${HRST}"
            echo -e "Delete a local branch:                             ${HSTL}git branch -d <branch>${HRST}"
            echo -e "Delete a remote branch:                            ${HSTL}git push origin --delete <branch>${HRST}"
            echo -e "Merge a branch into the current branch:            ${HSTL}git merge <branch>${HRST}"

            echo -e "\n${HCLR}Staging and Committing:${HRST}"
            echo -e "Stage changes:                                     ${HSTL}git add <file>${HRST} or ${HSTL}git add .${HRST}"
            echo -e "Commit changes with a message:                     ${HSTL}git commit -m \"message\"${HRST}"
            echo -e "Amend the last commit:                             ${HSTL}git commit --amend${HRST}"
            echo -e "Show commit history:                               ${HSTL}git log${HRST}"

            echo -e "\n${HCLR}Remote Commands:${HRST}"
            echo -e "Push current branch to remote:                     ${HSTL}git push${HRST}"
            echo -e "Push a specific branch to remote:                  ${HSTL}git push origin <branch>${HRST}"
            echo -e "Pull latest changes from remote branch:            ${HSTL}git pull origin <branch>${HRST}"
            echo -e "Fetch updates from remote without merging:         ${HSTL}git fetch${HRST}"
            echo -e "Add a new remote repository:                       ${HSTL}git remote add <name> <url>${HRST}"
            echo -e "List all remotes:                                  ${HSTL}git remote -v${HRST}"

            echo -e "\n${HCLR}Undo and Cleanup Commands:${HRST}"
            echo -e "Discard all local changes:                         ${HSTL}git checkout -- <file>${HRST} or ${HSTL}git reset --hard${HRST}"
            echo -e "Unstage changes (keep in working directory):       ${HSTL}git reset <file>${HRST}"
            echo -e "Reset branch to match remote:                      ${HSTL}git reset --hard origin/<branch>${HRST}"
            echo -e "Remove untracked files and directories:            ${HSTL}git clean -fd${HRST}"

            echo -e "\n${HCLR}Custom Git Commands:${HRST}"
            echo -e "Set Git user details and personal settings:        ${HSTL}git_login${HRST}"
            echo -e "Add all, commit, push to the current branch:       ${HSTL}git_push <message>${HRST}"
            echo -e "Add all, commit, push to a specified branch:       ${HSTL}git_push <branch> <message>${HRST}\n"
            ;;

        -conda)
            echo -e "\n${HCLR}Anaconda Env Management:${HRST}";
            echo -e "List all environments:                             ${HSTL}conda env list${HRST}";
            echo -e "Create a new environment:                          ${HSTL}conda create --name <env_name>${HRST}";
            echo -e "Create environment from requirements.yml:          ${HSTL}conda env create -f requirements.yml${HRST}";
            echo -e "Activate an environment:                           ${HSTL}conda activate <env_name>${HRST}";
            echo -e "Deactivate current environment:                    ${HSTL}conda deactivate${HRST}";
            echo -e "Remove an environment:                             ${HSTL}conda env remove --name <env_name>${HRST}";
            echo -e "Clone an environment:                              ${HSTL}conda create --name <new_env> --clone <existing_env>${HRST}";
            
            echo -e "\n${HCLR}Package Management:${HRST}";
            echo -e "Install a package:                                 ${HSTL}conda install <package_name>${HRST}";
            echo -e "Install specific version:                          ${HSTL}conda install <package_name>=<version>${HRST}";
            echo -e "Install multiple packages:                         ${HSTL}conda install <package1> <package2>${HRST}";
            echo -e "Install from specific channel:                     ${HSTL}conda install -c <channel> <package>${HRST}";
            echo -e "Update all packages:                               ${HSTL}conda update --all${HRST}";
            echo -e "Update specific package:                           ${HSTL}conda update <package_name>${HRST}";
            echo -e "Remove a package:                                  ${HSTL}conda remove <package_name>${HRST}";
            
            echo -e "\n${HCLR}Environment Information:${HRST}";
            echo -e "List packages in current environment:              ${HSTL}conda list${HRST}";
            echo -e "Search for a package:                              ${HSTL}conda search <package_name>${HRST}";
            echo -e "Show environment information:                      ${HSTL}conda info${HRST}";
            echo -e "Export environment to YAML:                        ${HSTL}conda env export > environment.yml${HRST}";
            echo -e "Show current environment name:                     ${HSTL}echo \$CONDA_DEFAULT_ENV${HRST}";
            
            echo -e "\n${HCLR}Maintenance and Updates:${HRST}"
            echo -e "Clean unused packages and caches:                  ${HSTL}conda clean --all${HRST}";
            echo -e "Update conda itself:                               ${HSTL}conda update conda${HRST}";
            echo -e "Update anaconda metapackage:                       ${HSTL}conda update anaconda${HRST}";
            echo -e "Verify conda installation:                         ${HSTL}conda verify${HRST}";
            
            echo -e "\n${HCLR}Pip Integration:${HRST}";
            echo -e "Install pip in current environment:                ${HSTL}conda install pip${HRST}";
            echo -e "Install package using pip:                         ${HSTL}pip install <package_name>${HRST}";
            echo -e "Export pip requirements:                           ${HSTL}pip freeze > requirements.txt${HRST}";
            
            echo -e "\n${HCLR}Jupyter Integration:${HRST}";
            echo -e "Install Jupyter Notebook:                          ${HSTL}conda install jupyter${HRST}";
            echo -e "Install JupyterLab:                                ${HSTL}conda install jupyterlab${HRST}";
            echo -e "Launch Jupyter Notebook:                           ${HSTL}jupyter notebook${HRST}";
            echo -e "Launch JupyterLab:                                 ${HSTL}jupyter lab${HRST}";

            echo -e "\n${HCLR}Custom Conda Commands:${HRST}"
            echo -e "Run Python scripts in a Conda environment:         ${HSTL}conda_run <environment> <script> [packages]${HRST}\n";
            ;;

        *)
            # Default help message
            echo -e "\n${HCLR}Available Sections (Use -<flag> to view details):${HRST}"
            echo -e "${HSTL}-gen${HRST}         General utilities and system setup commands."
            echo -e "${HSTL}-setup${HRST}       User preferences and environment setup."
            echo -e "${HSTL}-install${HRST}     Installation and update commands."
            echo -e "${HSTL}-net${HRST}         Networking and communication tools."
            echo -e "${HSTL}-dev${HRST}         Development tools and programming utilities."
            echo -e "${HSTL}-media${HRST}       Media processing commands."
            echo -e "${HSTL}-nerd${HRST}        Nerd Dictation setup and commands."
            echo -e "${HSTL}-dict${HRST}        Command and flag dictionary."
            echo -e "${HSTL}-git${HRST}         Git commands and utilities."
            echo -e "${HSTL}-conda${HRST}       Anaconda commands and utilities.\n"
            ;;
    esac
}

# Export common functions for use in subshells
export -f closing copy_dir change_owner remove_files install_flatpak install_dpkg \
install_apt updatefix convert_to_mp4 conda_run git_push add_gpg insert_script;

# Export application installation functions for use in subshells
export -f install_nordvpn install_rust install_R install_javascript install_py;

echo "Welcome to the Linux environment. Type 'help' to see available functions.";

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

# Home for public keys
mkdir -p "$HOME/.ssh/pubkeys/yubikey"
chmod 700 "$HOME/.ssh"
chmod 700 "$HOME/.ssh/pubkeys"
chmod 700 "$HOME/.ssh/pubkeys/yubikey"

# <CSF-E>

# Code below is outside of the CSF tags and will not be included in the bashrc file
# Code below is outside of the CSF tags and will not be included in the bashrc file
# Code below is outside of the CSF tags and will not be included in the bashrc file

