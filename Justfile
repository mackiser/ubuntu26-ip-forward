# Show available commands (default)
default:
    @just --list

# Create the virtualenv and install test dependencies (run once per clone)
setup:
    python3 -m venv .venv
    .venv/bin/pip install --upgrade pip
    .venv/bin/pip install "molecule" "molecule-plugins[docker]" "pytest" "pytest-testinfra"
    @echo "Done. Run 'just test' to test."

# Run the Molecule test suite
test:
    @test -x .venv/bin/molecule || (echo "venv not found — run 'just setup' first" && exit 1)
    @test -S "$HOME/.docker/run/docker.sock" -o -S /var/run/docker.sock || { echo "Docker socket not found — is Docker Desktop running?"; exit 1; }
    @export DOCKER_HOST="$(test -S "$HOME/.docker/run/docker.sock" && echo "unix://$HOME/.docker/run/docker.sock" || echo unix:///var/run/docker.sock)"; echo "Using DOCKER_HOST=$DOCKER_HOST"; .venv/bin/molecule test

# Create containers and apply the task, leaving them running for inspection
converge:
    @test -x .venv/bin/molecule || (echo "venv not found — run 'just setup' first" && exit 1)
    @test -S "$HOME/.docker/run/docker.sock" -o -S /var/run/docker.sock || { echo "Docker socket not found — is Docker Desktop running?"; exit 1; }
    @export DOCKER_HOST="$(test -S "$HOME/.docker/run/docker.sock" && echo "unix://$HOME/.docker/run/docker.sock" || echo unix:///var/run/docker.sock)"; echo "Using DOCKER_HOST=$DOCKER_HOST"; .venv/bin/molecule converge

# Log into a test container. Pass the name: ubuntu-26 or ubuntu-24
login container:
    @test -x .venv/bin/molecule || (echo "venv not found — run 'just setup' first" && exit 1)
    @test -S "$HOME/.docker/run/docker.sock" -o -S /var/run/docker.sock || { echo "Docker socket not found — is Docker Desktop running?"; exit 1; }
    @export DOCKER_HOST="$(test -S "$HOME/.docker/run/docker.sock" && echo "unix://$HOME/.docker/run/docker.sock" || echo unix:///var/run/docker.sock)"; echo "Using DOCKER_HOST=$DOCKER_HOST"; .venv/bin/molecule login --host {{container}}

# Tear down Molecule containers and any leftover manual test containers
destroy:
    @test -x .venv/bin/molecule || (echo "venv not found — run 'just setup' first" && exit 1)
    @test -S "$HOME/.docker/run/docker.sock" -o -S /var/run/docker.sock || { echo "Docker socket not found — is Docker Desktop running?"; exit 1; }
    @export DOCKER_HOST="$(test -S "$HOME/.docker/run/docker.sock" && echo "unix://$HOME/.docker/run/docker.sock" || echo unix:///var/run/docker.sock)"; echo "Using DOCKER_HOST=$DOCKER_HOST"; .venv/bin/molecule destroy
    -@docker rm -f ubuntu26-test ubuntu24-test 2>/dev/null
    @echo "All test containers destroyed."