#!/bin/bash

print_msg() {
    local type=$1
    shift
    local msg=$*

    case "$type" in
        success)
            echo -e "[\033[1;32m+\033[0m] $msg"  # Green +
            ;;
        info)
            echo -e "[\033[1;34m+\033[0m] $msg"  # Blue +
            ;;
        fail)
            echo -e "[\033[1;31m✗\033[0m] $msg"  # Red ✗
            ;;
        warning)
            echo -e "[\033[1;33m!\033[0m] $msg"  # Yellow !
            ;;
        *)
            echo "[?] $msg"
            ;;
    esac
}

if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    print_msg fail "This directory is not inside a Git repository."
    exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
CURRENT_DIR=$(pwd)

if [ "$CURRENT_DIR" != "$REPO_ROOT" ]; then
    print_msg fail "You must run this script from the root of the repository:"
    echo "   cd $REPO_ROOT"
    exit 1
fi

# Check that docker is accessible
print_msg info "Checking if Docker is installed..."
if ! command -v docker &> /dev/null; then
    print_msg fail "Docker is not installed. Please install Docker first."
    exit 1
fi
print_msg success "Docker is installed."

print_msg info "Checking if Docker is accessible..."
if ! docker info &> /dev/null; then
    print_msg fail "Docker is installed but not accessible."
    echo "   Try running with sudo or add your user to the docker group:"
    echo "   sudo usermod -aG docker \$USER"
    echo "   Then log out and back in for changes to take effect."
    exit 1
fi
print_msg success "Docker is accessible."

# Check if the container already exists
if docker ps -a --format '{{.Names}}' | grep -Eq "^firmainc-postgres\$"; then
    print_msg info "Container 'firmainc-postgres' already exists. Restarting it..."
    docker start firmainc-postgres &> /dev/null
    if [ $? -ne 0 ]; then
        print_msg fail "Failed to restart the existing container."
        exit 1
    fi
else
    print_msg info "Creating a new PostgreSQL container..."
    docker run -d \
        --name firmainc-postgres \
        -e POSTGRES_PASSWORD=firmadyne \
        -e POSTGRES_USER=firmadyne \
        -e POSTGRES_DB=firmware \
        -e PGDATA=/var/lib/postgresql/data/pgdata \
        -v $REPO_ROOT/database:/var/lib/postgresql/data \
        -p 5432:5432 \
        postgres &> /dev/null
    if [ $? -ne 0 ]; then
        print_msg fail "Failed to start the PostgreSQL container."
        exit 1
    fi
fi

# Wait for the container to start
while ! docker exec firmainc-postgres pg_isready -U firmadyne &> /dev/null; do
    sleep 1
done

print_msg success "PostgreSQL started successfully."

if docker exec -i firmainc-postgres psql -U firmadyne -d firmware -c "\dt" | grep -q "image"; then
    print_msg info "Database schema already applied. Skipping schema application."
else
    print_msg info "Applying database schema..."
    docker exec -i firmainc-postgres psql -U firmadyne -d firmware < "$REPO_ROOT/database/schema" &> /dev/null
    if [ $? -ne 0 ]; then
        print_msg fail "Could not populate database"
        exit 1
    fi
    print_msg success "Database schema applied successfully."
fi

print_msg success "firmware database populated"

print_msg info "Creating Python enviroment"

# Check if the Python virtual environment already exists
if [ "$VIRTUAL_ENV" != "" ]; then
    print_msg info "Python virtual environment already exists. Skipping creation."
    print_msg info "Using existing virtual environment: $VIRTUAL_ENV"
elif [ -d "$REPO_ROOT/.env" ]; then
    print_msg info "Python virtual environment already exists. Skipping creation."
    source "$REPO_ROOT/.env/bin/activate"
    print_msg info "Using existing virtual environment: $VIRTUAL_ENV"
else
    print_msg info "Creating Python virtual environment..."
    python3 -m venv "$REPO_ROOT/.env"
    if [ $? -ne 0 ]; then
        print_msg fail "Failed to create Python virtual environment."
        exit 1
    fi
    source "$REPO_ROOT/.env/bin/activate"
    print_msg success "Python virtual environment created successfully."
fi

# Install binwalk
if ! command -v binwalk &> /dev/null; then
    print_msg info "Binwalk not found. Installing..."

    print_msg info "Installing Binwalk..."
    wget -q https://github.com/George-RG/binwalk/archive/refs/tags/v2.3.5.tar.gz -O binwalk.tar.gz
    if [ $? -ne 0 ]; then
        print_msg fail "Failed to download Binwalk."
        exit 1
    fi
    tar -xzf binwalk.tar.gz
    rm binwalk.tar.gz
    cd "./binwalk-2.3.5" || exit
    ./deps.sh --yes &> /dev/null
    pip install . &> /dev/null
    if [ $? -ne 0 ]; then
        print_msg fail "Failed to install Binwalk."
        exit 1
    fi
    cd - &> /dev/null || exit
    rm -rf "./binwalk-2.3.5"


    print_msg success "Binwalk installed successfully"

else
    print_msg info "Binwalk is already installed."
fi

# Install sasquatch
if ! command -v sasquatch &> /dev/null; then
    print_msg info "Sasquatch not found. Installing..."
    
    sudo apt-get install build-essential liblzma-dev liblzo2-dev zlib1g-dev

    rm -rf sasquatch
    mkdir sasquatch
    cd sasquatch || exit

    wget https://downloads.sourceforge.net/project/squashfs/squashfs/squashfs4.3/squashfs4.3.tar.gz
    if [ $? -ne 0 ]; then
        print_msg fail "Failed to download SquashFS."
        exit 1
    fi

    # Remove any previous squashfs4.3 directory to ensure a clean patch/build
    rm -rf squashfs4.3

    # Extract squashfs4.3.tar.gz
    tar -zxvf squashfs4.3.tar.gz

    wget https://raw.githubusercontent.com/devttys0/sasquatch/82da12efe97a37ddcd33dba53933bc96db4d7c69/patches/patch0.txt
    if [ $? -ne 0 ]; then
        print_msg fail "Failed to download Sasquatch patch."
        exit 1
    fi

    cd squashfs4.3 || exit
    # Apply the patch
    patch -p0 < patch0.txt
    cd squashfs-tools || exit
    make &> /dev/null
    if [ $? -ne 0 ]; then
        print_msg fail "Failed to build SquashFS tools."
        exit 1
    fi

    sudo make install &> /dev/null
    if [ $? -ne 0 ]; then
        print_msg fail "Failed to install SquashFS tools."
        exit 1
    fi
    
    ./build.sh &> /dev/null
    if [ $? -ne 0 ]; then
        print_msg fail "Failed to build Sasquatch."
        exit 1
    fi
    print_msg success "Sasquatch installed successfully."
    cd ../../.. || exit
    rm -rf sasquatch
else
    print_msg info "Sasquatch is already installed."
fi

# Install Jeferson
# Install Jefferson
if ! command -v jefferson &> /dev/null; then
    print_msg info "Jefferson not found. Installing..."

    sudo apt install liblzo2-dev

    rm -rf jefferson
    git clone https://github.com/sviehb/jefferson.git
    if [ $? -ne 0 ]; then
        print_msg fail "Failed to clone Jefferson repository."
        exit 1
    fi
    cd jefferson || exit
    pip install -r requirements.txt &> /dev/null
    if [ $? -ne 0 ]; then
        print_msg fail "Failed to install Jefferson dependencies."
        exit 1
    fi
    pip install . &> /dev/null
    if [ $? -ne 0 ]; then
        print_msg fail "Failed to install Jefferson."
        exit 1
    fi
    print_msg success "Jefferson installed successfully."
    cd .. || exit
    rm -rf jefferson
else
    print_msg info "Jefferson is already installed."
fi

# Activate the virtual environment and install requirements
if [ -f "$REPO_ROOT/requirements.txt" ]; then
    print_msg info "Installing Python dependencies from requirements.txt..."
    pip install -r "$REPO_ROOT/requirements.txt" &> /dev/null
    if [ $? -ne 0 ]; then
        print_msg fail "Failed to install Python dependencies."
        exit 1
    fi
    print_msg success "Python dependencies installed successfully."
else
    print_msg warning "No requirements.txt found. Skipping dependency installation."
fi

if [ -d "$REPO_ROOT/analyses/routersploit" ]; then
    if [ "$(ls -A "$REPO_ROOT/analyses/routersploit")" ]; then
        pip install -r "$REPO_ROOT/analyses/routersploit/requirements.txt" &> /dev/null
        cd "$REPO_ROOT/analyses/routersploit" && patch -p1 < ../routersploit_patch && cd "$REPO_ROOT" &> /dev/null
        print_msg info "Routersploit configured successfully."
    else
        print_msg warning "Routersploit was not found. Skipping (this may affect analyses)."
    fi
else
    print_msg warning "Routersploit was not found. Skipping (this may affect analyses)."
fi

