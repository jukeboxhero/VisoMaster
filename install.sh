#!/bin/bash
set -e
WORKDIR="/workspace"

echo "=== 1. Moving Files to Workspace Root ==="
# Moves your pre-patched repo files from the temporary clone location into the main workspace
cd ..
mv VisoMaster /workspace/VisoMaster_Temp
rm -rf VisoMaster
mv /workspace/VisoMaster_Temp /workspace/VisoMaster
cd /workspace/VisoMaster

echo "=== 2. Installing Linux OS & VNC Display Servers ==="
apt-get update && apt-get install -y xvfb x11vnc fluxbox novnc websockify ffmpeg \
    libxcb-cursor0 libxkbcommon-x11-0 libxcb-icccm4 libxcb-image0 \
    libxcb-keysyms1 libxcb-randr0 libxcb-render-util0 libxcb-xinerama0 \
    libxcb-xfixes0 libegl1

echo "=== 3. Cleaning OpenCV GUI Conflict Layers ==="
rm -f /usr/local/lib/python3.11/dist-packages/cv2/qt/plugins/platforms/libqxcb.so || true

echo "=== 4. Bulk Installing Core Python Packages & NumPy 1.x ==="
mkdir -p "$WORKDIR/pip_cache"
export TMPDIR="$WORKDIR/pip_cache"
pip install PySide6 pyqt-toast-notification qtawesome qdarkstyle pyqtdarktheme \
    pyvirtualcam scikit-image kornia facexlib dynamic-yaml super-image gdown \
    opencv-python-headless onnx protobuf --cache-dir="$WORKDIR/pip_cache" --no-cache-dir
pip install "numpy<2.0" --force-reinstall --cache-dir="$WORKDIR/pip_cache" --no-cache-dir
pip install onnxruntime-gpu==1.19.0 --extra-index-url https://visualstudio.com --cache-dir="$WORKDIR/pip_cache" --no-cache-dir

echo "=== 5. Downloading AI Weights ==="
python download_models.py

echo "=== 6. Generating Bootstrapper Script ==="
cat << 'EOF' > run_app.sh
#!/bin/bash
pkill -9 -f main.py || true
pkill -9 -f websockify || true
pkill -9 -f x11vnc || true
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 || true
export LD_LIBRARY_PATH=/usr/local/lib/python3.11/dist-packages/tensorrt_libs:/usr/lib/x86_64-linux-gnu:/usr/local/cuda/lib64:$LD_LIBRARY_PATH
export PATH=/usr/local/cuda/bin:$PATH
Xvfb :1 -screen 0 1920x1080x24 &
sleep 1
export DISPLAY=:1
fluxbox &
sleep 1
websockify --web=/usr/share/novnc/ 8000 localhost:5900 &
x11vnc -display :1 -nopw -listen localhost -forever &
sleep 1
python main.py
EOF
chmod +x run_app.sh

echo "=== SETUP COMPLETE! STARTING VISOMASTER ==="
./run_app.sh
