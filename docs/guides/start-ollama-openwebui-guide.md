# Ollama and Open Web UI Start Guide

## Overview

This guide explains how to use the [`start-ollama-openwebui.sh`](../../scripts/ai/start-ollama-openwebui.sh) script to start Ollama and Open Web UI services on Fedora Linux systems.

### What is Ollama?

Ollama is a tool for running large language models (LLMs) locally on your machine. It provides a simple command-line interface for downloading, running, and managing various AI models.

### What is Open Web UI?

Open Web UI is a user-friendly web interface for interacting with LLMs, including those running through Ollama. It provides a chat-like interface, model management, and conversation history.

### Why Use This Script?

The start script provides:
- Quick startup of both services
- Status checking before starting
- Ctrl+C trap to cleanly stop both services
- Colored output for better user experience

## Usage

```bash
# Start both services
./scripts/ai/start-ollama-openwebui.sh
```

## Access Points

- **Open Web UI**: http://localhost:8080
- **Ollama API**: http://127.0.0.1:11434

## How It Works

1. **Checks status** of both services
2. **Starts Ollama** if not running
3. **Starts Open Web UI** if not running
4. **Displays access points** in your browser
5. **Waits for Ctrl+C** to stop both services

## Stopping Services

Press **Ctrl+C** to stop both Ollama and Open Web UI services. The script will:
1. Stop Ollama service
2. Stop Open Web UI container
3. Exit cleanly

## Common Issues

### "Ollama service not found"
**Solution**: Install Ollama first:
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### "Open Web UI container not found"
**Solution**: Run setup first or manually create the container:
```bash
podman pull ghcr.io/open-webui/open-webui:main
podman run -d \
  --network=host \
  -v open-webui:/app/backend/data \
  -e OLLAMA_BASE_URL=http://127.0.0.1:11434 \
  --name open-webui \
  --restart always \
  ghcr.io/open-webui/open-webui:main
```

### Services already running
The script checks if services are already running and skips starting them if they are.

## Related Scripts

- **[`update-ollama-openwebui.sh`](update-ollama-openwebui-guide.md)** - Update both services with backup
- **[`setup-ollama-openwebui.sh`](../setup-ollama-openwebui-guide.md)** - Initial installation (if you need it)

## Additional Resources

- [Ollama Documentation](https://ollama.com/docs)
- [Open Web UI GitHub](https://github.com/open-webui/open-webui)
- [Full Guide](../ollama-openwebui-guide.md) - Comprehensive guide with all details
