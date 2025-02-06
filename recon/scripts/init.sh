#!/bin/bash

# Create tools directory
PROJECT_TOOLS_FOLDER="$PWD/recon/tools"
if [ ! -d "$PROJECT_TOOLS_FOLDER" ]; then
  mkdir -p "$PROJECT_TOOLS_FOLDER"
fi

# Detect shell type
detect_shell() {
  # CURRENT_SHELL=$(ps -p $$ -o comm=)
  CURRENT_SHELL=$(basename "$SHELL")  # Checks the default shell set in the environment
  echo "Default login shell: $CURRENT_SHELL"
  echo "Current shell: $CURRENT_SHELL"

  if echo "$CURRENT_SHELL" | grep -q "zsh"; then
    SHELL_TYPE="zsh"
    SHELL_RC_FILE=~/.zshrc
  elif echo "$CURRENT_SHELL" | grep -q "bash"; then
    SHELL_TYPE="bash"
    SHELL_RC_FILE=~/.bashrc
  else
    echo "Error: Unsupported shell. Please use bash or zsh."
    exit 1
  fi
  echo "Detected shell: $SHELL_TYPE"
}

# Check Bash version
check_bash_version() {
  required_version="5.0"  # Set this to the minimum version required

  if [[ "$SHELL_TYPE" == "bash" ]]; then
    bash_version=$(bash --version | head -n 1 | sed 's/.*\(version [^ ]*\).*/\1/' | awk '{print $2}')
    echo "Current Bash version: $bash_version"

    # Compare installed version with the required version
    if [[ $(echo -e "$required_version\n$bash_version" | sort -V | head -n 1) != "$required_version" ]]; then
      echo "Error: Bash version $required_version or higher is required. You are running $bash_version."
      exit 1
    fi
  fi
  return 0  # Success
}

# Install Bash if the version is too old or missing (Linux / macOS)
install_bash() {
  # Check if Bash is installed and if it's the correct version
  check_bash_version
  bash_installed=$?

  # If bash isn't installed or the version is outdated, install/update it
  if [[ "$bash_installed" -ne 0 ]]; then
    echo "Installing/updating Bash to version $required_version..."

    # Check OS and install Bash accordingly
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
      # For Linux (Debian-based systems)
      if command -v apt-get &> /dev/null; then
        sudo apt update
        sudo apt upgrade -y
        sudo apt install bash -y
      elif command -v yum &> /dev/null; then
        sudo yum update -y
        sudo yum upgrade -y
        sudo yum install bash -y
      else
        echo "Unsupported package manager. Please install Bash manually."
        exit 1
      fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
      # For macOS (using Homebrew)
      if ! command -v brew &> /dev/null; then
        echo "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      fi
      # brew update
      brew install bash
      which bash

    else
      echo "Unsupported OS. Please install Bash manually."
      exit 1
    fi

    # After installation, recheck the Bash version
    check_bash_version
    if [[ $? -ne 0 ]]; then
      echo "Failed to install the correct Bash version. Please install Bash manually."
      exit 1
    fi
  fi
}

# Check if Go is installed and in PATH
check_go() {
  if ! command -v go &> /dev/null; then
    echo "Go is not installed. Installing Go..."
    # Ensure installation steps for Go (this example assumes Linux/macOS)
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
      sudo apt update && sudo apt install -y golang
    elif [[ "$OSTYPE" == "darwin"* ]]; then
      if ! command -v brew &> /dev/null; then
        echo "Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      fi
      brew install go
    else
      echo "Unsupported OS. Install Go manually."
      exit 1
    fi
  fi
}

# Add Go binary path to shell profile if not already added
add_go_path() {
  if ! grep -q "$HOME/go/bin" "$SHELL_RC_FILE"; then
    echo "Adding Go binary path to PATH in $SHELL_RC_FILE..."
    echo 'export PATH=$PATH:$HOME/go/bin' >> "$SHELL_RC_FILE"
    source "$SHELL_RC_FILE"
  fi
}



# Function to install packages with pipx from a given file
pipx_install_packages_from_file() {
    local package_file="$1"

    # Check if the file exists
    if [[ ! -f "$package_file" ]]; then
        echo "Package list file '$package_file' not found!"
        return 1
    fi

    # Iterate over each line in the package file and install it using pipx
    while IFS= read -r package; do
        if [[ -n "$package" ]]; then  # Ensure the line is not empty
            echo "Installing $package with pipx..."
            pipx run pip install --no-cache-dir "$package"
        fi
    done < "$package_file"
}




# Install tools
install_tools() {
  set -e
  echo "Installing tools..."
  amass_install
  subfinder_install
  assetfinder_install
  katana_install
  gau_install
  # dnsrecon_install

}
# git clone https://github.com/rthalley/dnspython
# cd dnspython/
# python setup.py install
#
#install_dnspython() {
#  echo "Installing dnspython..."
#  pushd "$PROJECT_TOOLS_FOLDER" || exit 1
#  echo "Cloning dnspython repository..."
#  git clone https://github.com/rthalley/dnspython.git
#  cd dnspython || exit 1
#  echo "Installing dnspython..."
#  python3 setup.py install
#  if python3 -c "import dns" &> /dev/null; then
#    echo "dnspython installed successfully."
#  else
#    echo "dnspython installation failed."
#    exit 1
#  fi
#  popd
#}

#install_dnspython() {
#  echo "Installing dnspython..."
#  pushd "$PROJECT_TOOLS_FOLDER" || exit 1
#
#  # Remove existing directory if it exists
#  if [ -d "dnspython" ]; then
#    echo "Cleaning up existing dnspython directory..."
#    rm -rf dnspython
#  fi
#
#  git clone https://github.com/rthalley/dnspython.git
#  cd dnspython || exit 1
#  python3 setup.py install
#
#  # Verify installation properly
#  if ! python3 -c "import dns" &> /dev/null; then
#    echo "Failed to install dnspython"
#    exit 1
#  fi
#  popd
#}

# https://github.com/lc/gau.git
gau_install() {
  echo "Installing gau..."
  pushd "$PROJECT_TOOLS_FOLDER" || exit 1
  if [ ! -d "gau" ]; then
    echo "Cloning gau repository..."
    git clone "https://github.com/lc/gau.git" "gau"
  fi
  popd
  go install github.com/lc/gau/v2/cmd/gau@latest

  if command -v gau &> /dev/null; then
    echo "gau installed successfully."
  else
    echo "gau installation failed."
    exit 1
  fi

}

amass_install() {
  echo "Installing Amass..."
  pushd "$PROJECT_TOOLS_FOLDER" || exit 1
  if [ ! -d "amass" ]; then
    echo "Cloning Amass repository..."
    git clone "https://github.com/OWASP/Amass.git" "amass"
  fi
  cd "amass" || exit 1
  if [ ! -f "Dockerfile" ]; then
    echo "Building Amass Docker image..."
    docker build --progress=plain -t "amass" .
  fi
  popd
  add_alias "amass" "docker run -v \"$PROJECT_TOOLS_FOLDER/amass:/root/.config/amass\" --rm -it amass"
}

subfinder_install() {
  pushd "$PROJECT_TOOLS_FOLDER" || exit 1
  if [ ! -d "subfinder" ]; then
    echo "Cloning Subfinder repository..."
    git clone "https://github.com/projectdiscovery/subfinder.git" "subfinder"
  fi
  popd
  if command -v subfinder &> /dev/null; then
    echo "Subfinder is already installed."
    return 0  # Exit the function early if subfinder is already installed
  fi
  echo "Installing Subfinder..."
  go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
  if command -v subfinder &> /dev/null; then
    echo "Subfinder installed successfully."
  else
    echo "Subfinder installation failed."
    exit 1
  fi
}

assetfinder_install(){
  echo "Installing assetfinder..."
  pushd "$PROJECT_TOOLS_FOLDER" || exit 1
  if [ ! -d "assetfinder" ]; then
    echo "Cloning assetfinder repository..."
    git clone "https://github.com/tomnomnom/assetfinder.git" "assetfinder"
  fi
  popd
  if command -v assetfinder &> /dev/null; then
    echo "assetfinder is already installed."
    return 0  # Exit the function early if assetfinder is already installed
  fi
  echo "Installing assetfinder..."
  go install github.com/tomnomnom/assetfinder@latest
  if command -v assetfinder &> /dev/null; then
    echo "assetfinder installed successfully."
  else
    echo "assetfinder installation failed."
    exit 1
  fi

}
# https://github.com/OJ/gobuster.git
gobuster_install(){
  echo "Installing gobuster..."
  pushd "$PROJECT_TOOLS_FOLDER" || exit 1
  if [ ! -d "gobuster" ]; then
    echo "Cloning gobuster repository..."
    git clone "https://github.com/OJ/gobuster.git" "gobuster"
  fi
  popd
  if command -v gobuster &> /dev/null; then
    echo "gobuster is already installed."
    return 0  # Exit the function early if gobuster is already installed
  fi
    echo "Installing gobuster..."
    go install github.com/OJ/gobuster/v3@latest
    if command -v gobuster &> /dev/null; then
    echo "gobuster installed successfully."
  else
    echo "gobuster installation failed."
    exit 1
  fi
}

# have a problem - in dns - not ready yet
# https://github.com/darkoperator/dnsrecon.git
dnsrecon_install() {
  echo "Installing dnsrecon..."
  pushd "$PROJECT_TOOLS_FOLDER" || exit 1
  if [ ! -d "dnsrecon" ]; then
    echo "Cloning dnsrecon repository..."
    git clone "https://github.com/darkoperator/dnsrecon.git" "dnsrecon"
  fi
  cd "dnsrecon" || exit 1
  # Install required Python packages
  echo "Installing dnsrecon dependencies..."
  pipx_install_packages_from_file requirements.txt
  ln -s "$PROJECT_TOOLS_FOLDER/dnsrecon/dnsrecon.py" /usr/local/bin/dnsrecon
  chmod +x /usr/local/bin/dnsrecon
  popd
  if command -v dnsrecon &> /dev/null; then
    echo "dnsrecon installed successfully."
  else
    echo "dnsrecon installation failed."
    exit 1
  fi

}

# https://github.com/projectdiscovery/httpx
httpx_install() {
  echo "Installing httpx..."
  pushd "$PROJECT_TOOLS_FOLDER" || exit 1
  if [ ! -d "httpx" ]; then
    echo "Cloning httpx repository..."
    git clone "https://github.com/projectdiscovery/httpx.git" "httpx"
  fi
  popd
  echo "Installing httpx ..."
  go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
  if command -v httpx &> /dev/null; then
    echo "httpx installed successfully."
  else
    echo "httpx installation failed."
    exit 1
  fi
}

# https://github.com/projectdiscovery/katana
katana_install() {
  echo "Installing katana..."
  pushd "$PROJECT_TOOLS_FOLDER" || exit 1
  if [ ! -d "katana" ]; then
    echo "Cloning katana repository..."
    git clone "https://github.com/projectdiscovery/katana.git" "katana"
  fi
  popd
  echo "Installing katana ..."
  CGO_ENABLED=1 go install github.com/projectdiscovery/katana/cmd/katana@latest
  if command -v katana &> /dev/null; then
    echo "katana installed successfully."
  else
    echo "katana installation failed."
    exit 1
  fi
}


add_alias() {
  local tool_name=$1
  local alias_cmd=$2
  echo "Adding alias for $tool_name to $SHELL_RC_FILE"  # Debugging line
  if ! grep -q "alias $tool_name=" "$SHELL_RC_FILE"; then
    echo "alias $tool_name='$alias_cmd'" >> "$SHELL_RC_FILE"
    echo "Alias added for $tool_name."
    echo "Alias added for $tool_name to $SHELL_RC_FILE."  # Confirmation

    source "$SHELL_RC_FILE"
  else
    echo "Alias for $tool_name already exists."
  fi
}

install_pipx_if_missing() {
  if ! command -v pipx &> /dev/null; then
    echo "pipx is not installed. Installing..."
    python3 -m pip install pipx
  fi
}


# initialize environment
install_pipx_if_missing
# pipx install openpyxl
# Set the Python path
PYTHON_EXE=$(command -v python3)
export PATH=$PATH:$PYTHON_EXE
detect_shell
install_bash
check_go
add_go_path
#install_dnspython
install_tools
echo "Sourcing shell configuration file..."
source "$SHELL_RC_FILE"
echo "Tools initialized successfully with project-based configurations."
