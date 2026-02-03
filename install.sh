#!/bin/bash
set -e

APP_WM_CLASS="fogstripper"

echo "============================================================"
echo "  FOGSTRIPPER - INSTALACAO SIMPLIFICADA"
echo "  AVISO: Este processo pode levar alguns minutos."
echo "============================================================"
echo ""

# Definir diretorios
APP_DIR="$HOME/.local/share/fogstripper"
PROJECT_ROOT=$(pwd)
VENV_DIR="$APP_DIR/venv"
PYTHON_EXEC="$VENV_DIR/bin/python3"

# Configurar TMPDIR local para evitar falta de espaco em /tmp
# Isso resolve o problema de travamento no basicsr/realesrgan
export TMPDIR="$HOME/.pip_tmp_fogstripper"
mkdir -p "$TMPDIR"
echo ">> Configurando diretorio temporario: $TMPDIR"

# Limpar instalacao antiga
if [ -d "$APP_DIR" ]; then
    echo ">> Removendo instalacao anterior..."
    rm -rf "$APP_DIR"
fi
mkdir -p "$APP_DIR"

echo ">> Gerando icones..."
python3 -m venv "$VENV_DIR"
"$PYTHON_EXEC" -m pip install --upgrade pip setuptools wheel > /dev/null
"$PYTHON_EXEC" -m pip install Pillow > /dev/null
"$PYTHON_EXEC" "$PROJECT_ROOT/src/utils/icon_resizer.py" "$PROJECT_ROOT"
echo ">> Icones gerados."

echo ""
echo "[1/3] Configurando ambiente virtual unificado..."
# Instalando PyTorch primeiro para garantir binarios
echo ">> Instalando Core e PyTorch (isso ajuda a evitar compilacao desnecessaria)..."
"$PYTHON_EXEC" -m pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cu118 || \
"$PYTHON_EXEC" -m pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cpu

echo ""
echo "[2/3] Instalando demais dependencias (pode demorar um pouco)..."
# Instalando o resto do requirements.txt
"$PYTHON_EXEC" -m pip install --no-cache-dir -r ./requirements.txt

echo ""
echo "[3/3] Configurando sistema..."

echo ">> Criando arquivo de configuracao..."
# Agora usamos o MESMO python para tudo, pois unificamos o venv
cat > "$APP_DIR/config.json" << EOL
{
    "PYTHON_REMBG": "$PYTHON_EXEC",
    "PYTHON_UPSCALE": "$PYTHON_EXEC",
    "REMBG_SCRIPT": "$APP_DIR/src/workers/worker_rembg.py",
    "UPSCALE_SCRIPT": "$APP_DIR/src/workers/worker_upscale.py",
    "EFFECTS_SCRIPT": "$APP_DIR/src/workers/worker_effects.py",
    "BACKGROUND_SCRIPT": "$APP_DIR/src/workers/worker_background.py"
}
EOL

# Copiando arquivos fonte
echo ">> Copiando arquivos..."
mkdir -p "$APP_DIR/src"
cp -r ./src/* "$APP_DIR/src/"
cp -r ./assets "$APP_DIR/"
cp ./uninstall.sh "$APP_DIR/" && chmod +x "$APP_DIR/uninstall.sh"

echo ">> Instalando atalhos..."
for size in 16 32 64 128; do
    ICON_DIR="$HOME/.local/share/icons/hicolor/${size}x${size}/apps"
    mkdir -p "$ICON_DIR"
    cp "$PROJECT_ROOT/assets/generated_icons/icon_${size}x${size}.png" "$ICON_DIR/fogstripper.png"
done

DESKTOP_INSTALL_DIR="$HOME/.local/share/applications"
mkdir -p "$DESKTOP_INSTALL_DIR"
cat > "$DESKTOP_INSTALL_DIR/fogstripper.desktop" << EOL
[Desktop Entry]
Name=FogStripper
Comment=Removedor de fundo de imagens
Exec=env PYTHONPATH=$APP_DIR $PYTHON_EXEC $APP_DIR/src/main.py
Icon=fogstripper
Type=Application
Categories=Graphics;
Terminal=false
StartupWMClass=$APP_WM_CLASS
EOL

update-desktop-database -q "$DESKTOP_INSTALL_DIR"
gtk-update-icon-cache -q -f -t "$HOME/.local/share/icons/hicolor"

# Limpeza
rm -rf "$TMPDIR"
echo ">> Limpeza concluida."

echo ""
echo "######################################################################"
echo "INSTALACAO CONCLUIDA COM SUCESSO!"
echo "Pode iniciar pelo menu de aplicativos."
echo "######################################################################"
