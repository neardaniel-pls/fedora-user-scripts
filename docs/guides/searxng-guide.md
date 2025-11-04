# SearXNG Self-Hosting Guide for Fedora

This guide provides step-by-step instructions to install, configure, and run a self-hosted SearXNG instance on a Fedora system.

## Installation

Install required dependencies:

```bash
sudo dnf install -y python3-pip python3-devel python3-babel python3-virtualenv uwsgi uwsgi-plugin-python3 git gcc make libxslt-devel zlib-devel libffi-devel openssl-devel
```

Clone and set up SearXNG:

```bash
mkdir -p ~/Documents/code/searxng
cd ~/Documents/code/searxng
git clone "https://github.com/searxng/searxng"
python3 -m venv searxng-venv
source searxng-venv/bin/activate
pip install -U pip setuptools wheel pyyaml lxml
cd searxng
pip install --use-pep517 --no-build-isolation -e .
```

## Configuration

Create and configure settings:

```bash
sudo mkdir -p /etc/searxng
cd ~/Documents/code/searxng/searxng
sudo cp searx/settings.yml /etc/searxng/settings.yml
sudo sed -i "s|ultrasecretkey|$(openssl rand -hex 32)|g" /etc/searxng/settings.yml
export SEARXNG_SETTINGS_PATH="/etc/searxng/settings.yml"
deactivate
```

## Running SearXNG

Use the provided script:

```bash
./run-searxng.sh
```

Or run manually:

```bash
cd ~/Documents/code/searxng
source searxng-venv/bin/activate
cd searxng
python3 searx/webapp.py
```

Access your instance at `http://127.0.0.1:8888`.

## Customization

Click "Preferences" in your SearXNG instance to:
- Switch between light and dark themes
- Enable preferred search engines
- Modify URL presentation to remove trackers
- Configure SafeSearch and auto-complete

To save preferences, allow cookies for `http://127.0.0.1:8888` in your browser.

## Updating

Use the update script:

```bash
cd ~/Documents/code/searxng/searxng
./update-searxng.sh
```

Or update manually:

```bash
cd ~/Documents/code/searxng/searxng
git pull "https://github.com/searxng/searxng"
```

## Troubleshooting

### Common Issues

- **Port already in use**: Check with `lsof -i :8888` or use different port with `SEARXNG_PORT=9000 ./run-searxng.sh`
- **Settings file not found**: Verify `/etc/searxng/settings.yml` exists and is readable
- **Git pull failures**: Check for uncommitted changes with `git status`

### Error Messages

- `Address already in use`: Another process is using port 8888
- `Permission denied`: Check file permissions for settings and scripts

## Security Considerations

- Store `/etc/searxng/settings.yml` securely with restricted access
- Regularly update SearXNG for security patches
- For internet-facing instances, use a reverse proxy with TLS/HTTPS
- Keep your Fedora system updated: `sudo dnf update -y`

---

**Last Updated**: October 2025