# Guide: Open Web UI Installation with Podman

## 1. Overview

Open Web UI is a user-friendly and extensible web interface for various LLMs (Large Language Models). This guide will walk you through setting up the application in a containerized environment using Podman, which is the default container engine on modern Fedora systems.

The setup involves:
- Installing Podman
- Pulling the Open Web UI container image
- Running the container and making it accessible
- Installing Ollama to run models locally
- Pulling and running models from Hugging Face
- (Optional) Disabling Ollama autostart and managing it manually
- (Optional) Creating a systemd service for automatic startup

## 2. Dependencies

- **Podman**: The container engine used to run Open Web UI
- **`sudo`**: Required for system-level commands, including installing packages and managing systemd services

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

To run the application, you need to create a container from the image you just pulled. This command starts the container, maps the necessary port, and configures networking for local model access.

```bash
# podman run -d \
#   --name open-webui \
#   -p 8080:8080 \
#   -v open-webui:/app/backend/data \
#   --add-host=host.docker.internal:host-gateway \
#   -e WEBUI_HOST=0.0.0.0 \
#   ghcr.io/open-webui/open-webui:main
podman run -d \
  --name open-webui \
  --network=host \
  -v open-webui:/app/backend/data \
  -e WEBUI_HOST=0.0.0.0 \
  ghcr.io/open-webui/open-webui:main  
```

**Command Breakdown:**
- `-d`: Runs the container in detached mode (in the background)
- `--name open-webui`: Assigns a memorable name to the container
- `-p 8080:8080`: Maps port 8080 on your local machine to port 8080 inside the container. You will access the UI via `http://localhost:8080`
- `-v open-webui:/app/backend/data`: Creates a Podman volume named `open-webui` to persist application data. This is crucial for retaining your settings and chat history
- `--add-host=host.docker.internal:host-gateway`: Allows the container to communicate with services running on your host machine, including Ollama
- `-e WEBUI_HOST=0.0.0.0`: Configures the web interface to listen on all network interfaces

### Step 4: Access Open Web UI

Once the container is running, open your web browser and navigate to:

```
http://localhost:8080
```

You should see the Open Web UI interface, where you can create your first admin account.

### Step 5: Install Ollama for Local Models

To run LLMs locally, you need to install Ollama.

1. **Download and run the installer**:
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

This command downloads and executes the official installation script.

2. **Verify the installation**:

After the script finishes, Ollama will be installed and the systemd service will be created. By default, the installer enables the Ollama service to start automatically on boot.

### Step 6: Disable Ollama Autostart (Optional)

If you only want to run Ollama when you need Open Web UI, you can disable the autostart behavior. This prevents Ollama from consuming resources when you're not using it.

**Disable autostart:**
```bash
sudo systemctl disable ollama
```

**Verify it's disabled:**
```bash
sudo systemctl status ollama
```

You should see `disabled` in the output.

### Step 7: Manage Ollama Manually

With autostart disabled, you can now start and stop Ollama as needed.

**Start Ollama:**
```bash
sudo systemctl start ollama
```

**Stop Ollama:**
```bash
sudo systemctl stop ollama
```

**Check Ollama status:**
```bash
sudo systemctl status ollama
```

**Restart Ollama:**
```bash
sudo systemctl restart ollama
```

### Step 8: Pull a Model from Hugging Face

With Ollama running, you can now pull models. To pull a GGUF model from Hugging Face, use the `ollama run` command with the `hf.co` prefix.

**Example:**
```bash
ollama run hf.co/DavidAU/OpenAi-GPT-oss-20b-abliterated-uncensored-NEO-Imatrix-gguf:Q5_1

ollama run hf.co/unsloth/Qwen3-4B-Thinking-2507-GGUF:Q6_K
```

This command will download the specified model and start a chat session in your terminal. Once the model is downloaded, you can exit the terminal chat by typing `/bye`. The model is now available for Open Web UI to use.

### Step 9: Connect Open Web UI to Ollama

By default, Open Web UI should automatically detect your local Ollama instance at `http://host.docker.internal:11434`.

1. In the Open Web UI interface, click **"Select a model"**
2. You should see the model you just downloaded in the list (e.g., `OpenAi-GPT-oss-20b-abliterated-uncensored-NEO-Imatrix-gguf:Q5_1`)
3. Select it to start chatting

If Open Web UI cannot find your Ollama instance, you may need to explicitly configure the connection:
- Go to **Settings** → **Admin Panel** → **Models**
- Set the Ollama API URL to `http://localhost:11434`

## 4. Managing the Container

Here are some useful commands for managing the `open-webui` container.

**Check container status:**
```bash
podman ps
```
*(Use `podman ps -a` to see all containers, including stopped ones)*

**View container logs:**
```bash
podman logs -f open-webui
```
*(The `-f` flag follows the log output in real-time)*

**Stop the container:**
```bash
podman stop open-webui
```

**Start the container:**
```bash
podman start open-webui
```

**Remove the container:**
*(You must stop the container before removing it)*
```bash
podman rm open-webui
```

## 5. Typical Workflow

If you've disabled Ollama autostart, here's a typical workflow for using Open Web UI:

1. **Start Ollama:**
```bash
sudo systemctl start ollama
```

2. **Start the Open Web UI container** (if not already running):
```bash
podman start open-webui
```

3. **Access Open Web UI** in your browser at `http://localhost:8080`

4. **When finished**, stop the services:
```bash
podman stop open-webui
sudo systemctl stop ollama
```

This prevents both services from consuming system resources when you're not actively using them.

## 6. Complete Uninstall

If you want to remove everything and start fresh, follow these steps carefully. This will remove Open Web UI, Ollama, all downloaded models, and associated configuration files.

### Remove Open Web UI Container and Volume

**Stop and remove the container:**
```bash
podman stop open-webui
podman rm open-webui
```

**Remove the Open Web UI volume** (this will delete all your Open Web UI data, conversations, and settings):
```bash
podman volume rm open-webui
```

**Remove the Open Web UI image** (optional, if you want to free up disk space):
```bash
podman image rm ghcr.io/open-webui/open-webui:main
```

### Remove Ollama

**Stop the Ollama service:**
```bash
sudo systemctl stop ollama
```

**Disable the Ollama service:**
```bash
sudo systemctl disable ollama
```

**Remove the Ollama systemd service file:**
```bash
sudo rm /etc/systemd/system/ollama.service
```

**Remove the Ollama binary:**
```bash
sudo rm $(which ollama)
```

**Remove Ollama configuration and user data:**
```bash
rm -rf ~/.ollama
```

**Remove Ollama system-wide data** (this contains all downloaded models):
```bash
sudo rm -rf /usr/share/ollama
```

**Remove Ollama user and group:**
```bash
sudo userdel ollama
sudo groupdel ollama
```

### Delete Individual Models (Without Uninstalling Ollama)

If you want to keep Ollama installed but only remove specific models:

**List all installed models:**
```bash
ollama list
```

**Remove a specific model:**
```bash
ollama rm <model_name>
```

**Example:**
```bash
ollama rm hf.co/DavidAU/OpenAi-GPT-oss-20b-abliterated-uncensored-NEO-Imatrix-gguf:Q5_1
```

**Verify the model was deleted:**
```bash
ollama list
```

### Clean Up Podman (Optional)

After removing the Open Web UI container, you can optionally clean up unused Podman resources:

**Remove all stopped containers:**
```bash
podman system prune -f
```

**Remove all stopped containers and unused images:**
```bash
podman system prune -a -f
```

**Remove all stopped containers, unused images, and dangling volumes:**
```bash
podman system prune -a -f --volumes
```

### Verify Complete Removal

To confirm everything has been removed:

**Check for Ollama:**
```bash
which ollama
systemctl status ollama
```

Both should return "not found" or errors.

**Check for Open Web UI container:**
```bash
podman ps -a | grep open-webui
```

This should return nothing.

**Check for Podman volumes:**
```bash
podman volume ls | grep open-webui
```

This should return nothing.

**Check disk space to see what was freed:**
```bash
df -h
```

## 7. Troubleshooting

### "cannot connect to container" or "address already in use"

**Symptom**: The container fails to start, and logs show errors related to port conflicts.

**Solution**: Another service on your machine is likely using port 8080. You can identify what is using it with:

```bash
sudo lsof -i :8080
```

Either stop the conflicting service or modify the port mapping in your `podman run` command. For example, to use port 3000 instead:

```bash
podman run -d --name open-webui -p 3000:8080 \
  -v open-webui:/app/backend/data \
  --add-host=host.docker.internal:host-gateway \
  -e WEBUI_HOST=0.0.0.0 \
  ghcr.io/open-webui/open-webui:main
```

Then access the UI at `http://localhost:3000`.

### Data is not persisting after restarts

**Symptom**: All settings and chat history are lost after restarting the container.

**Solution**: This usually means the volume was not correctly mounted. Ensure the `-v open-webui:/app/backend/data` part of your `podman run` command is present. You can inspect your container's configuration with:

```bash
podman inspect open-webui
```

Look for the **"Mounts"** section to verify the volume is attached.

### Open Web UI cannot connect to Ollama

**Symptom**: The model selection dropdown is empty, or you see connection errors in the logs.

**Solution**: First, verify that Ollama is actually running:

```bash
sudo systemctl status ollama
```

If it's not running, start it with:

```bash
sudo systemctl start ollama
```

Then verify that Ollama is accessible:

```bash
curl http://localhost:11434
```

If this returns "Ollama is running," then the connection is working. If Open Web UI still cannot connect, try setting the Ollama base URL explicitly in the container environment:

```bash
podman stop open-webui
podman rm open-webui
podman run -d --name open-webui -p 8080:8080 \
  -v open-webui:/app/backend/data \
  --add-host=host.docker.internal:host-gateway \
  -e WEBUI_HOST=0.0.0.0 \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  ghcr.io/open-webui/open-webui:main
```

### Ollama service won't stop

**Symptom**: You try to stop Ollama with `systemctl stop ollama`, but it keeps restarting.

**Solution**: Make sure you haven't re-enabled autostart. Check the service status:

```bash
sudo systemctl is-enabled ollama
```

If it shows `enabled`, disable it:

```bash
sudo systemctl disable ollama
```

Then try stopping it again:

```bash
sudo systemctl stop ollama
```

---

**Last Updated**: November 2025