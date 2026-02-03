#!/bin/bash
set -e

VERSION="${1:-1.0.0}"
ARCH="amd64"
PACKAGE_NAME="fogstripper"
BUILD_DIR="build_deb"
DEB_NAME="${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"

echo ">> Iniciando criacao do pacote .deb..."

# Limpar build anterior
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/DEBIAN"
mkdir -p "$BUILD_DIR/opt/fogstripper"
mkdir -p "$BUILD_DIR/usr/bin"
mkdir -p "$BUILD_DIR/usr/share/applications"
mkdir -p "$BUILD_DIR/usr/share/icons/hicolor"

# 1. Copiar arquivos da aplicacao para /opt
echo ">> Copiando arquivos..."
cp -r src "$BUILD_DIR/opt/fogstripper/"
cp -r assets "$BUILD_DIR/opt/fogstripper/"
cp requirements.txt "$BUILD_DIR/opt/fogstripper/"
cp uninstall.sh "$BUILD_DIR/opt/fogstripper/"

# 2. Criar Control File
echo ">> Criando arquivo de controle..."
cat > "$BUILD_DIR/DEBIAN/control" << EOL
Package: $PACKAGE_NAME
Version: $VERSION
Architecture: $ARCH
Maintainer: FogStripper Team <noreply@fogstripper.dev>
Depends: python3, python3-pip, python3-venv, git, wget
Section: graphics
Priority: optional
Description: FogStripper - Removedor de Fundo
 Aplicacao desktop para remover fundos de imagens e videos
 usando redes neurais (rembg) e realizar upscale (Real-ESRGAN).
EOL

# 3. Criar Postinst (Script pos-instalacao)
# Este script cria o venv e instala as dependencias na maquina do usuario
echo ">> Criando script postinst..."
cat > "$BUILD_DIR/DEBIAN/postinst" << EOL
#!/bin/bash
set -e

APP_DIR="/opt/fogstripper"
VENV_DIR="\$APP_DIR/venv"
PYTHON_EXEC="\$VENV_DIR/bin/python3"

echo ">> Configurando FogStripper em \$APP_DIR..."

if [ ! -d "\$VENV_DIR" ]; then
    echo ">> Criando ambiente virtual..."
    python3 -m venv "\$VENV_DIR"
fi

echo ">> Instalando dependencias (isso pode demorar)..."
# Usar um TMPDIR local para evitar problemas de espaco
export TMPDIR="/var/tmp/fogstripper_pip"
mkdir -p "\$TMPDIR"

"\$PYTHON_EXEC" -m pip install --no-cache-dir --upgrade pip setuptools wheel
# PyTorch CPU para compatibilidade geral
"\$PYTHON_EXEC" -m pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cpu
"\$PYTHON_EXEC" -m pip install --no-cache-dir -r "\$APP_DIR/requirements.txt"

rm -rf "\$TMPDIR"

echo ">> Gerando configuracao..."
cat > "\$APP_DIR/config.json" << JSON
{
    "PYTHON_REMBG": "\$PYTHON_EXEC",
    "PYTHON_UPSCALE": "\$PYTHON_EXEC",
    "REMBG_SCRIPT": "\$APP_DIR/src/workers/worker_rembg.py",
    "UPSCALE_SCRIPT": "\$APP_DIR/src/workers/worker_upscale.py",
    "EFFECTS_SCRIPT": "\$APP_DIR/src/workers/worker_effects.py",
    "BACKGROUND_SCRIPT": "\$APP_DIR/src/workers/worker_background.py"
}
JSON

# Permissoes
chmod -R 755 "\$APP_DIR"
chmod +x "\$APP_DIR/uninstall.sh"

echo ">> FogStripper configurado com sucesso!"
exit 0
EOL
chmod 755 "$BUILD_DIR/DEBIAN/postinst"

# 4. Criar Prerm (Script pre-remocao)
echo ">> Criando script prerm..."
cat > "$BUILD_DIR/DEBIAN/prerm" << EOL
#!/bin/bash
set -e
rm -rf /opt/fogstripper/venv
rm -rf /opt/fogstripper/config.json
rm -rf /opt/fogstripper/__pycache__
exit 0
EOL
chmod 755 "$BUILD_DIR/DEBIAN/prerm"

# 5. Criar Launcher em /usr/bin
echo ">> Criando launcher..."
cat > "$BUILD_DIR/usr/bin/fogstripper" << EOL
#!/bin/bash
exec /opt/fogstripper/venv/bin/python3 /opt/fogstripper/src/main.py "\$@"
EOL
chmod 755 "$BUILD_DIR/usr/bin/fogstripper"

# 6. Criar Desktop File
echo ">> Criando atalho .desktop..."
cat > "$BUILD_DIR/usr/share/applications/fogstripper.desktop" << EOL
[Desktop Entry]
Name=FogStripper
Comment=Removedor de fundo de imagens
Exec=/usr/bin/fogstripper
Icon=fogstripper
Type=Application
Categories=Graphics;Utility;
Terminal=false
StartupWMClass=FogStripper
EOL

# 7. Copiar Icones
echo ">> Copiando icones..."
for size in 16 32 64 128; do
    ICON_DEST="$BUILD_DIR/usr/share/icons/hicolor/${size}x${size}/apps"
    mkdir -p "$ICON_DEST"
    cp "assets/generated_icons/icon_${size}x${size}.png" "$ICON_DEST/fogstripper.png"
done

# 8. Build
echo ">> Construindo pacote (dpkg-deb)..."
dpkg-deb --build "$BUILD_DIR" "$DEB_NAME"

echo ">> Pacote criado: $DEB_NAME"
rm -rf "$BUILD_DIR"
