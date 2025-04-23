#!bin/bash

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

# TODO maybe a good idea is to use --restartand not --rm but needs check if container exists

# Setup postgrss database
docker run -d --rm\
    --name firmainc-postgres \
    -e POSTGRES_PASSWORD=firmadyne \
    -e POSTGRES_USER=firmadyne \
    -e POSTGRES_DB=firmware \
    -e PGDATA=/var/lib/postgresql/data/pgdata \
    -v $REPO_ROOT/database:/var/lib/postgresql/data \
    -p 4321:5432 \
    postgres &> /dev/null

if [ $? -ne 0 ]; then
    print_msg fail "Failed to start the PostgreSQL container."
    exit 1
fi

# Wait for the container to start
while ! docker exec firmainc-postgres pg_isready -U firmadyne &> /dev/null; do
    sleep 1
done

print_msg success "PostgreSQL started successfully."

# Run the schema inside the postgress container using psql
docker exec -i firmainc-postgres psql -U firmadyne -d firmware < "$REPO_ROOT/database/schema" &> /dev/null

if [ $? -ne 0 ]; then
    print_msg fail "Could not populate database"
    exit 1
fi

print_msg success "firmware database populated"
