# SearXNG Self-Hosting Guide for Fedora

This guide provides step-by-step instructions to install, configure, and run a self-hosted SearXNG instance on a Fedora system.

## 1. Installation

First, install the required dependencies using `dnf`.

```bash
sudo dnf install -y python3-pip python3-devel python3-babel python3-virtualenv uwsgi uwsgi-plugin-python3 git gcc make libxslt-devel zlib-devel libffi-devel openssl-devel
```

Next, clone the SearXNG repository and set up the Python virtual environment.

```bash
mkdir -p ~/Documentos/searxng
cd ~/Documentos/searxng
git clone "https://github.com/searxng/searxng"
python3 -m venv searxng-venv
source searxng-venv/bin/activate
pip install -U pip setuptools wheel pyyaml lxml
cd searxng
pip install --use-pep517 --no-build-isolation -e .
```

## 2. Configuration

Now, configure your SearXNG instance. This involves creating a settings file and generating a secret key.

```bash
sudo mkdir -p /etc/searxng
cd ~/Documentos/searxng/searxng
sudo cp searx/settings.yml /etc/searxng/settings.yml
sudo sed -i "s|ultrasecretkey|$(openssl rand -hex 32)|g" /etc/searxng/settings.yml
export SEARXNG_SETTINGS_PATH="/etc/searxng/settings.yml"
deactivate
```

Your machine is now configured to run the SearXNG software.

## 3. Running the Application

To run the SearXNG web application, use the provided `run-searxng.sh` script:

```bash
./run-searxng.sh
```

This script will validate your environment, detect port conflicts, and provide helpful error messages if something goes wrong. It also handles graceful shutdown with Ctrl+C.

Alternatively, you can run the application manually:

```bash
cd ~/Documentos/searxng
source searxng-venv/bin/activate
cd searxng
python3 searx/webapp.py
```

The software is now running. You can access your instance by navigating to `http://127.0.0.1:8888` in your web browser. The service will continue to run as long as the terminal window is open.

## 4. Customization and Preferences

From your SearXNG instance, click the "Preferences" link to customize your search experience. You can:
- Disable auto-complete and SafeSearch
- Switch between light and dark themes
- Open results in new tabs
- Enable preferred search engines
- Modify how URLs are presented to remove trackers

To save your preferences, you need to allow cookies for your local instance in your browser settings.

### For Firefox:
1. Navigate to Firefox's **Settings** menu and click **Privacy & Security**.
2. Click **Manage Exceptions…** next to "Delete cookies and site data when Firefox is closed".
3. Enter the URL of your SearXNG instance (`http://127.0.0.1:8888`) and click **Allow**.
4. Click **Save Changes**.

## 5. Updating SearXNG

To update your SearXNG instance to the latest version, use the provided `update-searxng.sh` script:

```bash
cd ~/Documentos/searxng/searxng
./update-searxng.sh
```

This script will verify the repository, check for uncommitted changes, and safely pull the latest updates from the official repository. It handles both `main` and `master` branches automatically.

Alternatively, you can update manually:

```bash
cd ~/Documentos/searxng/searxng
git pull "https://github.com/searxng/searxng"
```

## 6. Troubleshooting

### Port Already in Use
If you see "Address already in use" error, another process is running on port 8888. Check what's using the port:

```bash
lsof -i :8888
```

Kill the process or use a different port with `SEARXNG_PORT=9000 ./run-searxng.sh`.

### Settings File Not Found
Ensure the settings file exists and is readable:

```bash
ls -l /etc/searxng/settings.yml
```

If missing, recreate it:

```bash
sudo cp ~/Documentos/searxng/searxng/searx/settings.yml /etc/searxng/settings.yml
```

### Git Pull Failures
If updates fail with git errors, check your uncommitted changes:

```bash
cd ~/Documentos/searxng/searxng
git status
```

Stash or commit any uncommitted changes before updating.

## 7. Security Considerations

- Store your `/etc/searxng/settings.yml` securely and restrict access
- Regularly update SearXNG using the update script to get security patches
- For internet-facing instances, use a reverse proxy with TLS/HTTPS encryption
- Consider running SearXNG in a restricted user account rather than your main user
- Keep your Fedora system updated: `sudo dnf update -y`

## 8. Additional Resources

- [SearXNG Official Documentation](https://docs.searxng.org/)
- [SearXNG GitHub Repository](https://github.com/searxng/searxng)
- [Python Virtual Environments Guide](https://docs.python.org/3/tutorial/venv.html)