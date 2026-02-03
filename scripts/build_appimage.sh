#!/bin/bash
set -e

VERSION="${1:-1.0.0}"
ARCH="x86_64"
APP_NAME="FogStripper"
APPDIR="${APP_NAME}.AppDir"
OUTPUT_NAME="${APP_NAME}-${VERSION}-${ARCH}.AppImage"
APPIMAGETOOL="appimagetool-x86_64.AppImage"
APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"

echo ">> Iniciando criacao do AppImage v${VERSION}..."

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/lib/fogstripper"
mkdir -p "$APPDIR/usr/share/applications"
mkdir -p "$APPDIR/usr/share/icons/hicolor"

echo ">> Copiando arquivos da aplicacao..."
cp -r src "$APPDIR/usr/lib/fogstripper/"
cp -r assets "$APPDIR/usr/lib/fogstripper/"
cp requirements.txt "$APPDIR/usr/lib/fogstripper/"

echo ">> Copiando icones..."
for size in 16 32 64 128; do
    ICON_DIR="$APPDIR/usr/share/icons/hicolor/${size}x${size}/apps"
    mkdir -p "$ICON_DIR"
    cp "assets/generated_icons/icon_${size}x${size}.png" "$ICON_DIR/fogstripper.png"
done

if [ -f "assets/generated_icons/icon_128x128.png" ]; then
    cp "assets/generated_icons/icon_128x128.png" "$APPDIR/fogstripper.png"
elif [ -f "assets/icon.png" ]; then
    cp "assets/icon.png" "$APPDIR/fogstripper.png"
fi

echo ">> Criando desktop file..."
cat > "$APPDIR/fogstripper.desktop" << EOL
[Desktop Entry]
Name=FogStripper
Comment=Removedor de fundo de imagens
Exec=fogstripper
Icon=fogstripper
Type=Application
Categories=Graphics;Utility;
Terminal=false
StartupWMClass=FogStripper
EOL

cp "$APPDIR/fogstripper.desktop" "$APPDIR/usr/share/applications/"

echo ">> Criando AppRun..."
cat > "$APPDIR/AppRun" << 'APPRUN'
#!/bin/bash
SELF=$(readlink -f "$0")
APPDIR=$(dirname "$SELF")
APP_LIB="$APPDIR/usr/lib/fogstripper"
VENV_DIR="$APP_LIB/venv"
PYTHON_EXEC="$VENV_DIR/bin/python3"

setup_venv() {
    echo ">> Configurando FogStripper (primeira execucao)..."
    echo ">> Criando ambiente virtual..."
    python3 -m venv "$VENV_DIR"

    echo ">> Instalando dependencias (isso pode demorar)..."
    "$PYTHON_EXEC" -m pip install --no-cache-dir --upgrade pip setuptools wheel 2>&1 | tail -1

    "$PYTHON_EXEC" -m pip install --no-cache-dir \
        torch torchvision \
        --extra-index-url https://download.pytorch.org/whl/cpu 2>&1 | tail -1

    "$PYTHON_EXEC" -m pip install --no-cache-dir \
        -r "$APP_LIB/requirements.txt" 2>&1 | tail -1

    cat > "$APP_LIB/config.json" << CONF
{
    "PYTHON_REMBG": "$PYTHON_EXEC",
    "PYTHON_UPSCALE": "$PYTHON_EXEC",
    "REMBG_SCRIPT": "$APP_LIB/src/workers/worker_rembg.py",
    "UPSCALE_SCRIPT": "$APP_LIB/src/workers/worker_upscale.py",
    "EFFECTS_SCRIPT": "$APP_LIB/src/workers/worker_effects.py",
    "BACKGROUND_SCRIPT": "$APP_LIB/src/workers/worker_background.py"
}
CONF

    echo ">> Configuracao concluida!"
}

if [ ! -d "$VENV_DIR" ]; then
    setup_venv
fi

export PYTHONPATH="$APP_LIB"
exec "$PYTHON_EXEC" "$APP_LIB/src/main.py" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

if [ ! -f "$APPIMAGETOOL" ]; then
    echo ">> Baixando appimagetool..."
    wget -q "$APPIMAGETOOL_URL" -O "$APPIMAGETOOL"
    chmod +x "$APPIMAGETOOL"
fi

echo ">> Construindo AppImage..."
ARCH=$ARCH ./"$APPIMAGETOOL" "$APPDIR" "$OUTPUT_NAME"

echo ">> AppImage criado: $OUTPUT_NAME"
rm -rf "$APPDIR"
