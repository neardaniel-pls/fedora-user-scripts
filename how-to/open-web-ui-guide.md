# Guide: Open Web UI Installation with Podman

This guide provides step-by-step instructions for installing and running Open Web UI on a Fedora system using Podman.

## 1. Overview

Open Web UI is a user-friendly and extensible web interface for various LLMs (Large Language Models). This guide will walk you through setting up the application in a containerized environment using Podman, which is the default container engine on modern Fedora systems.

The setup involves:
- Installing Podman.
- Pulling the Open Web UI container image.
- Running the container and making it accessible.
- (Optional) Creating a systemd service for automatic startup.

## 2. Dependencies

- **Podman**: The container engine used to run Open Web UI.
- **`sudo`**: Required for system-level commands, including installing packages and managing systemd services.

## 3. Installation & Setup

### Step 1: Install Podman

If you do not have Podman installed, open a terminal and run the following command:

```bash
sudo dnf install podman
```

### Step 2: Pull the Open Web UI Image

Next, pull the official Open Web UI container image from a container registry. This command downloads the latest version.

```bash
podman pull ghcr.io/open-webui/open-webui:main
```

### Step 3: Run the Open Web UI Container

To run the application, you need to create a container from the image you just pulled. This command starts the container, maps the necessary port, and sets it to restart automatically.

```bash
podman run -d \
  --name open-webui \
  -p 8080:8080 \
  -v open-webui:/app/backend/data \
  --add-host=host.docker.internal:host-gateway \
  -e WEBUI_HOST=0.0.0.0 \
  ghcr.io/open-webui/open-webui:main
```

**Command Breakdown:**
- `-d`: Runs the container in detached mode (in the background).
- `--name open-webui`: Assigns a memorable name to the container.
- `-p 8080:8080`: Maps port 8080 on your local machine to port 8080 inside the container. You will access the UI via `http://localhost:8080`.
- `-v open-webui:/app/backend/data`: Creates a Podman volume named `open-webui` to persist application data. This is crucial for retaining your settings and chat history.
- `--restart=always`: Ensures the container automatically restarts if it stops.
  *Note: For user-level Podman containers, this flag does not guarantee startup after a system reboot unless user lingering is enabled. If you plan to use the Systemd service (Section 5), it is cleaner to omit this flag and rely solely on Systemd for automatic startup.*

### Step 4: Access Open Web UI

Once the container is running, open your web browser and navigate to:

[http://localhost:8080](http://localhost:8080)

You should see the Open Web UI interface, where you can create your first admin account.

## 4. Managing the Container

Here are some useful commands for managing the `open-webui` container.

- **Check container status**:
  ```bash
  podman ps
  ```
  *(Use `podman ps -a` to see all containers, including stopped ones.)*

- **View container logs**:
  ```bash
  podman logs -f open-webui
  ```
  *(The `-f` flag follows the log output in real-time.)*

- **Stop the container**:
  ```bash
  podman stop open-webui
  ```

- **Start the container**:
  ```bash
  podman start open-webui
  ```

- **Remove the container**:
  *(You must stop the container before removing it.)*
  ```bash
  podman rm open-webui
  ```

## 5. Troubleshooting

### "cannot connect to container" or "address already in use"

**Symptom**: The container fails to start, and logs show errors related to port conflicts.

**Solution**: Another service on your machine is likely using port 8080. You can either stop the conflicting service or map Open Web UI to a different port.

To use a different port (e.g., 8090), modify the `podman run` command:
```bash
podman run -d --name open-webui -p 8090:8080 ...
```
Then access the UI at `http://localhost:8090`.

### Data is not persisting after restarts

**Symptom**: All settings and chat history are lost after restarting the container.

**Solution**: This usually means the volume was not correctly mounted. Ensure the `-v open-webui:/app/backend/data` part of your `podman run` command is present. You can inspect your container's configuration with:
```bash
podman inspect open-webui
```
Look for the "Mounts" section to verify the volume is attached.

---

**Last Updated**: November 2025