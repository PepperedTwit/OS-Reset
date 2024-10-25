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

function discord() {

    install_dpkg Discord.deb; discord;

}

# shellcheck disable=SC2120
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
    );

    updatefix; install_apt "r-base"; 

    # Append additional packages if any are passed
    if [ "$#" -gt 0 ]; then Packages+=("$@"); fi

    # Get the R major and minor version dynamically
    local R_VERSION=$(R --slave -e 'cat(R.version$major, ".", strsplit(R.version$minor, "\\.")[[1]][1], sep="")');

    # Define the dynamic user library path
    local LIB="$HOME/R/x86_64-pc-linux-gnu-library/$R_VERSION";

    mkdir -p "$LIB";

    for pkg in "${Packages[@]}"; do

        # Check if the package is available on CRAN
        if ! sudo R --slave -e "repos <- c(CRAN='https://cran.csiro.au'); if (!(\"$pkg\" %in% rownames(available.packages(repos=repos)))) quit(status=1)"; then
            echo -e "$pkg is not available on the CRAN repository. Skipping.\n\n"; continue;
        fi

        # Check if the package is already installed
        if R --slave -e "if (!require('$pkg', quietly = TRUE)) quit(status=1)"; then
            echo -e "$pkg is already installed.\n\n";
        else
            # Install the package to the user library
            R --slave -e "install.packages('$pkg', repos='https://cran.csiro.au', lib='$LIB')";
            echo -e "$pkg has been installed successfully.\n\n";
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

function git_update() {

    if [ -z "$1" ]; then echo "No branch specified. Exiting."; return 1; fi

    if [ -z "$2" ]; then echo "No commit message specified. Exiting."; return 1; fi

    local branch msg;
    branch="$1"; shift; msg="$1";

    if ! git branch -a | grep -qE "(\s|remotes/origin/)$branch$"; then
        echo "Branch $branch does not exist. Exiting."; return 1; 
    fi

    git add .; git commit -m "$msg"; git push origin "$branch";

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
    echo "git_update - Commit changes to Git repository. Usage: git_update <branch> <message>";
    echo "convert_to_mp4 - Convert video files to MP4 format.";
    echo "copy_prefs - Copy preferences to the user directory.";
    echo "core_setup - Setup core system settings.";
    echo "setup_user - Setup user environment.";
    echo "help - Display this help message.";
    echo "";

}

# Export common functions for use in subshells
export -f closing copy_dir change_owner remove_files install_flatpak install_dpkg \
install_apt updatefix convert_to_mp4 run_py git_update add_gpg insert_script;

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
# <CSF-E>

# Code below is outside of the CSF tags and will not be included in the bashrc file
# Code below is outside of the CSF tags and will not be included in the bashrc file
# Code below is outside of the CSF tags and will not be included in the bashrc file

insert_script "./src/func.sh" "$HOME/.bashrc" -o;
