# CS421 Haskell Development Environment Setup

This guide helps you set up a Docker-based Haskell development environment so you don't need to install Stack/GHC directly on your machine.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed on your machine
- [VS Code](https://code.visualstudio.com/) (recommended)
- [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) for VS Code (recommended)

## Quick Start

### Option 1: Using VS Code Dev Containers (Recommended)

1. **Pull the image** (when available):
   ```bash
   docker pull mattox/cs421-haskell-dev:latest
   ```

2. **Open your project in VS Code**

3. **Create a `.devcontainer/devcontainer.json` file** in your project root:
**(this is already done for you in the release repository)**
   ```json
   {
     "name": "CS421 Haskell Dev",
     "image": "mattox/cs421-haskell-dev:latest",
     "customizations": {
       "vscode": {
         "extensions": [
           "haskell.haskell",
           "justusadam.language-haskell"
         ],
         "settings": {
           "terminal.integrated.defaultProfile.linux": "bash",
           "terminal.integrated.profiles.linux": {
             "bash": {
               "path": "/bin/bash",
               "args": ["-l"]
             }
           }
         }
       }
     },
     "workspaceMount": "source=${localWorkspaceFolder},target=/home/student/workspace,type=bind",
     "workspaceFolder": "/home/student/workspace",
     "remoteUser": "student",
     "postCreateCommand": "sudo chown -R student:student /home/student/workspace",
     "overrideCommand": true
   }
   ```

4. **Reopen in Container**: Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac), type "Dev Containers: Reopen in Container"

5. **Start coding!** Your project files are mounted in `/home/student/workspace`

### Option 2: Using Docker Directly

1. **Pull the image**:
   ```bash
   docker pull mattox/cs421-haskell-dev:latest
   ```

2. **Run the container** (from your project directory):
   ```bash
   docker run -it -v "$(pwd):/home/student/workspace" mattox/cs421-haskell-dev:latest
   ```

3. **Work in the terminal**:
   ```bash
   # Initialize Stack project (first time only)
   stack init --resolver lts-23.28

   # Build your project
   stack build

   # Run tests
   stack test

   # Start GHCi
   stack ghci
   ```

### Options 3: nix package manager

For those using `nix`, the `flake.nix` file should contain the dependencies you need.  If you don't
know what that meant just now, you can either ignore it safely or jump down the rabbit hole that is
nixos.

## Troubleshooting

### "Stack command not found"

Make sure you're running commands inside the Docker container, not on your host machine.

### Permission Issues with Files

The devcontainer is configured to automatically fix file permissions when the container starts (`postCreateCommand`). If you still encounter permission issues:

1. **Rebuild the container**: Press `Ctrl+Shift+P` → "Dev Containers: Rebuild Container"
2. **Manually fix inside container**: Open a terminal in VS Code and run:
   ```bash
   sudo chown -R student:student /home/student/workspace
   ```

This is normal when your host user has a different UID than the container's `student` user (UID 1000).

### GHC or Stack Not Found

Make sure your terminal is running bash with `-l` (login) flag to load the PATH. This should be automatic with the provided devcontainer config.

You can verify the setup by running:
```bash
ghc --version        # Should show GHC 9.8.4
stack --version      # Should show Stack 3.x
haskell-language-server-wrapper --version  # Should show HLS 2.x
```

### Slow Initial Build

The first `stack build` in a project will download dependencies. This is normal and will be cached for subsequent builds.

## VS Code Haskell Extension Setup

The Haskell extension and Haskell Language Server (HLS) are pre-installed in the container and should work automatically. HLS provides IDE features like:
- Code completion
- Error highlighting
- Jump to definition
- Hover documentation

## Getting Help

- Check on the class discord or office hours if you need help.
