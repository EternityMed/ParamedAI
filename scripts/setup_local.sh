#!/bin/bash
set -e
echo "=== ParaMed AI Local Setup ==="

echo "1. Setting up Python backend..."
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
echo "Backend dependencies installed."

echo "2. Setting up Flutter app..."
cd ../flutter_app
flutter pub get
echo "Flutter dependencies installed."

echo "3. Creating .env from template..."
cd ..
cp .env.example backend/.env
echo "Environment file created."

echo "=== Setup complete! ==="
echo "Run 'make backend' to start the backend server."
echo "Run 'make flutter' to start the Flutter app."
