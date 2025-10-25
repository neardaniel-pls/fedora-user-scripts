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

To run the SearXNG web application, follow these steps:

```bash
cd ~/Documentos/searxng
source searxng-venv/bin/activate
cd searxng
python3 searx/webapp.py
```

The software is now running. You can access your instance by navigating to `http://127.0.0.1:8888` in your web browser. The service will continue to run as long as the terminal window is open.

## 4. Customization and Preferences

From your SearXNG instance, click the "Preferences" link to customize your search experience. You can:
- Disable auto-complete and SafeSearch.
- Switch between light and dark themes.
- Open results in new tabs.
- Enable preferred search engines.
- Modify how URLs are presented to remove trackers.

To save your preferences, you need to allow cookies for your local instance in your browser settings.

### For Firefox:
1.  Navigate to Firefox’s **Settings** menu and click **Privacy & Security**.
2.  Click **Manage Exceptions…** next to "Delete cookies and site data when Firefox is closed".
3.  Enter the URL of your SearXNG instance (`http://127.0.0.1:8888`) and click **Allow**.
4.  Click **Save Changes**.

## 5. Updating SearXNG

To update your SearXNG instance to the latest version, you need to pull the latest changes from the official repository.

```bash
cd ~/Documentos/searxng/searxng
git pull "https://github.com/searxng/searxng"
```

Alternatively, you can run the `update-searxng.sh` script located in the `scripts` directory of this project to automate the update process.