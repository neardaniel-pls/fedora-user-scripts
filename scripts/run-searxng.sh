#!/bin/bash
# Script to run the searxng web application

# Change to the searxng project directory
cd ~/Documentos/searxng || exit

# Activate the Python virtual environment
source searxng-venv/bin/activate

# Change to the searxng application directory
cd searxng || exit

# Run the web application
python3 searx/webapp.py