#!/usr/bin/env bash
# =============================================================================
#  mint-estilo-mac.sh — Deixa o Linux Mint (Cinnamon) com visual de macOS
#  Tema WhiteSur (GTK + Cinnamon + ícones + cursor + wallpaper), painel no
#  topo, dock Plank com zoom, botões à esquerda, fonte Inter, painel
#  transparente e Ulauncher (estilo Spotlight, Ctrl+Espaço).
#
#  Uso:   chmod +x mint-estilo-mac.sh
#         ./mint-estilo-mac.sh          (claro: barra clara + maçã preta)
#         ./mint-estilo-mac.sh dark     (escuro: barra preta + maçã branca)
#  Rode como seu usuário normal (NÃO use sudo), dentro da sessão Cinnamon.
#  Reverter: dconf load /org/cinnamon/ < ~/mac-look-backup/cinnamon.dconf
# =============================================================================
set -uo pipefail

# ---------------------------- CONFIGURAÇÃO -----------------------------------
MODO="${1:-light}"   # light (padrão) ou dark — passe como argumento
PAPEL_LIGHT="Sonoma-light"   # Sonoma | Ventura | Monterey | WhiteSur  + -light
PAPEL_DARK="Sonoma-dark"     # Sonoma | Ventura | Monterey | WhiteSur  + -dark
INSTALAR_ULAUNCHER=1 # 1 = instala Ulauncher (Spotlight); 0 = pula
TAMANHO_ICONES_DOCK=48
ALTURA_PAINEL=28
# -----------------------------------------------------------------------------

export DEBIAN_FRONTEND=noninteractive
VERDE='\e[32m'; AMARELO='\e[33m'; VERMELHO='\e[31m'; NC='\e[0m'
info() { echo -e "${VERDE}==>${NC} $*"; }
warn() { echo -e "${AMARELO}[aviso]${NC} $*"; }
erro() { echo -e "${VERMELHO}[erro]${NC} $*"; exit 1; }

[[ $EUID -eq 0 ]] && erro "Não rode com sudo. Execute como seu usuário: ./mint-estilo-mac.sh"
command -v apt >/dev/null || erro "Este script é para Linux Mint / Ubuntu (apt)."
if [[ "${XDG_CURRENT_DESKTOP:-}" != *Cinnamon* ]]; then
  warn "Ambiente detectado: '${XDG_CURRENT_DESKTOP:-desconhecido}'. O script é feito para Cinnamon;"
  warn "os temas serão instalados, mas painel/dock podem não ser configurados."
fi

case "$MODO" in
  light) GTK="WhiteSur-Light"; ICONES="WhiteSur-light"; PLANK_TEMA="WhiteSur-Light"
         PAPEL="$PAPEL_LIGHT"; MACA="activities-black" ;;  # maçã preta
  dark)  GTK="WhiteSur-Dark";  ICONES="WhiteSur-dark";  PLANK_TEMA="WhiteSur-Dark"
         PAPEL="$PAPEL_DARK";  MACA="activities" ;;        # maçã branca
  *) erro "Uso: $0 [light|dark]" ;;
esac
CURSOR="WhiteSur-cursors"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

sudo -v || erro "Precisa da senha de administrador."
# mantém o sudo ativo durante a execução
( while true; do sudo -n true; sleep 50; done ) 2>/dev/null &
SUDO_KEEP=$!
trap 'kill $SUDO_KEEP 2>/dev/null; rm -rf "$TMP"' EXIT

# ----------------------------- 0. BACKUP -------------------------------------
info "Fazendo backup das configurações atuais em ~/mac-look-backup"
mkdir -p ~/mac-look-backup
dconf dump /org/cinnamon/ > ~/mac-look-backup/cinnamon.dconf 2>/dev/null || true
dconf dump /net/launchpad/plank/ > ~/mac-look-backup/plank.dconf 2>/dev/null || true

# ----------------------------- 1. PACOTES ------------------------------------
info "Atualizando e instalando dependências"
sudo apt update -y
sudo apt install -y git curl wget unzip dconf-cli sassc libglib2.0-dev-bin \
  libxml2-utils gtk2-engines-murrine gnome-themes-extra plank \
  || erro "Falha ao instalar dependências."
sudo apt install -y fonts-inter || warn "fonts-inter indisponível; mantendo a fonte atual."

# ----------------------------- 2. TEMAS --------------------------------------
clonar() { git clone --depth=1 "https://github.com/vinceliuice/$1.git" "$TMP/$1" >/dev/null 2>&1 \
           || { warn "Não consegui baixar $1"; return 1; }; }

info "Instalando tema GTK/Cinnamon WhiteSur"
if clonar WhiteSur-gtk-theme; then
  ( cd "$TMP/WhiteSur-gtk-theme" && yes | ./install.sh -c dark -c light -l ) \
    || warn "Instalação do tema GTK retornou erro (verifique ~/.themes)."
  # temas do Plank incluídos no repositório
  mkdir -p ~/.local/share/plank/themes
  while IFS= read -r f; do
    d="$(dirname "$f")"; n="$(basename "$d")"
    case "$n" in *[Ll]ight*) dest="WhiteSur-Light";; *) dest="WhiteSur-Dark";; esac
    rm -rf ~/.local/share/plank/themes/"$dest"; cp -r "$d" ~/.local/share/plank/themes/"$dest"
  done < <(find "$TMP/WhiteSur-gtk-theme/other/plank" -name dock.theme 2>/dev/null)
fi

info "Instalando ícones WhiteSur"
clonar WhiteSur-icon-theme && ( cd "$TMP/WhiteSur-icon-theme" && ./install.sh ) \
  || warn "Ícones não instalados."

info "Instalando cursor WhiteSur"
clonar WhiteSur-cursors && ( cd "$TMP/WhiteSur-cursors" && ./install.sh ) \
  || warn "Cursor não instalado."

info "Baixando papéis de parede"
WALL=""
mkdir -p ~/Imagens/Wallpapers-Mac 2>/dev/null || mkdir -p ~/Pictures/Wallpapers-Mac
WDIR="$( [[ -d ~/Imagens ]] && echo ~/Imagens/Wallpapers-Mac || echo ~/Pictures/Wallpapers-Mac )"
if clonar WhiteSur-wallpapers; then
  find "$TMP/WhiteSur-wallpapers" -type f \( -iname '*.jpg' -o -iname '*.png' \) \
       -path '*4k*' -exec cp -n {} "$WDIR"/ \; 2>/dev/null
  [[ -z "$(ls -A "$WDIR")" ]] && find "$TMP/WhiteSur-wallpapers" -type f \
       \( -iname '*.jpg' -o -iname '*.png' \) -exec cp -n {} "$WDIR"/ \;
  WALL="$WDIR/${PAPEL}.jpg"; [[ -f "$WALL" ]] || WALL="$(find "$WDIR" -iname "*${MODO}*" | head -n1)"
  [[ -z "$WALL" ]] && WALL="$(find "$WDIR" -type f | head -n1)"
fi

# ----------------------------- 3. APARÊNCIA ----------------------------------
info "Aplicando tema, ícones, cursor e fontes"
gsettings set org.cinnamon.desktop.interface gtk-theme   "$GTK"
gsettings set org.cinnamon.desktop.interface icon-theme  "$ICONES"
gsettings set org.cinnamon.desktop.interface cursor-theme "$CURSOR"
gsettings set org.cinnamon.desktop.wm.preferences theme  "$GTK"
gsettings set org.cinnamon.theme name                    "$GTK"
gsettings set org.gnome.desktop.interface gtk-theme      "$GTK"    2>/dev/null
gsettings set org.gnome.desktop.interface icon-theme     "$ICONES" 2>/dev/null
gsettings set org.gnome.desktop.interface cursor-theme   "$CURSOR" 2>/dev/null
gsettings set org.gnome.desktop.interface color-scheme   "prefer-$MODO" 2>/dev/null

# Botões da janela à esquerda (fechar, minimizar, maximizar)
gsettings set org.cinnamon.desktop.wm.preferences button-layout 'close,minimize,maximize:'
gsettings set org.gnome.desktop.wm.preferences   button-layout 'close,minimize,maximize:' 2>/dev/null

if fc-list | grep -qi "Inter"; then
  gsettings set org.cinnamon.desktop.interface font-name      'Inter 10'
  gsettings set org.gnome.desktop.interface   font-name       'Inter 10' 2>/dev/null
  gsettings set org.nemo.desktop              font            'Inter 10' 2>/dev/null
  gsettings set org.cinnamon.desktop.wm.preferences titlebar-font 'Inter Bold 10'
fi

if [[ -n "$WALL" ]]; then
  info "Definindo papel de parede: $(basename "$WALL")"
  gsettings set org.cinnamon.desktop.background picture-uri "file://$WALL"
  gsettings set org.cinnamon.desktop.background picture-options 'zoom'
fi

# ----------------------------- 4. PAINEL NO TOPO -----------------------------
info "Movendo o painel para o topo (estilo barra de menus do Mac)"
gsettings set org.cinnamon panels-enabled  "['1:0:top']"
gsettings set org.cinnamon panels-height   "['1:${ALTURA_PAINEL}']"
gsettings set org.cinnamon panels-autohide "['1:false']"
# Menu à esquerda; ícones de sistema e relógio à direita; sem lista de janelas
# (as janelas abertas passam a aparecer no dock)
gsettings set org.cinnamon enabled-applets "[
 'panel1:left:0:menu@cinnamon.org:0',
 'panel1:right:0:systray@cinnamon.org:3',
 'panel1:right:1:xapp-status@cinnamon.org:4',
 'panel1:right:2:notifications@cinnamon.org:5',
 'panel1:right:3:removable-drives@cinnamon.org:7',
 'panel1:right:4:keyboard@cinnamon.org:8',
 'panel1:right:5:network@cinnamon.org:10',
 'panel1:right:6:sound@cinnamon.org:11',
 'panel1:right:7:power@cinnamon.org:12',
 'panel1:right:8:calendar@cinnamon.org:13'
]"

info "Instalando extensão de painel transparente"
EXT="transparent-panels@germanfr"
if wget -q -O "$TMP/ext.zip" "https://cinnamon-spices.linuxmint.com/files/extensions/${EXT}.zip"; then
  mkdir -p ~/.local/share/cinnamon/extensions
  unzip -oq "$TMP/ext.zip" -d ~/.local/share/cinnamon/extensions/
  ATUAIS="$(gsettings get org.cinnamon enabled-extensions)"
  if [[ "$ATUAIS" != *"$EXT"* ]]; then
    if [[ "$ATUAIS" == "@as []" || "$ATUAIS" == "[]" ]]; then
      gsettings set org.cinnamon enabled-extensions "['$EXT']"
    else
      gsettings set org.cinnamon enabled-extensions "${ATUAIS%]}, '$EXT']"
    fi
  fi
else
  warn "Não consegui baixar a extensão de transparência (o tema WhiteSur já é translúcido)."
fi

# ----------------------------- 5. DOCK (PLANK) -------------------------------
info "Configurando o dock Plank"
pkill -x plank 2>/dev/null; sleep 1
LAUNCH=~/.config/plank/dock1/launchers
mkdir -p "$LAUNCH"; rm -f "$LAUNCH"/*.dockitem
ITENS=()
for app in nemo google-chrome firefox org.gnome.Terminal xed org.gnome.Calculator \
           libreoffice-writer libreoffice-calc mintinstall cinnamon-settings; do
  f="/usr/share/applications/${app}.desktop"
  [[ -f "$f" ]] || continue
  printf '[PlankDockItemPreferences]\nLauncher=file://%s\n' "$f" > "$LAUNCH/${app}.dockitem"
  ITENS+=("'${app}.dockitem'")
done
P="net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/"
gsettings set "$P" dock-items "[$(IFS=,; echo "${ITENS[*]}")]" 2>/dev/null
[[ -d ~/.local/share/plank/themes/$PLANK_TEMA ]] && gsettings set "$P" theme "$PLANK_TEMA" \
  || gsettings set "$P" theme 'Transparent'
gsettings set "$P" position        'bottom'
gsettings set "$P" alignment       'center'
gsettings set "$P" icon-size       "$TAMANHO_ICONES_DOCK"
gsettings set "$P" zoom-enabled    true
gsettings set "$P" zoom-percent    150
gsettings set "$P" hide-mode       'intelligent'
gsettings set "$P" show-dock-item  false

mkdir -p ~/.config/autostart
cat > ~/.config/autostart/plank.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Plank
Exec=plank
X-GNOME-Autostart-enabled=true
NoDisplay=false
EOF
nohup plank >/dev/null 2>&1 &

# ----------------------------- 5b. MAÇÃ NO MENU ------------------------------
SVG="$TMP/WhiteSur-gtk-theme/src/assets/gnome-shell/$MACA/activities-apple.svg"
CFG="$(ls ~/.config/cinnamon/spices/menu@cinnamon.org/*.json 2>/dev/null | head -n1)"
if [[ -f "$SVG" ]]; then
  info "Trocando o ícone do Mint pela maçã no menu"
  mkdir -p ~/.local/share/icons/mac-menu
  ICON=~/.local/share/icons/mac-menu/apple-menu-$MODO.svg
  cp "$SVG" "$ICON"
  if [[ -n "$CFG" ]]; then
    cp "$CFG" "$CFG.bak"
    python3 - "$CFG" "$ICON" <<'PY'
import json, sys
cfg, icon = sys.argv[1], sys.argv[2]
with open(cfg) as f: d = json.load(f)
for k, v in (("menu-custom", True), ("menu-icon", icon), ("menu-label", "")):
    if k in d and isinstance(d[k], dict): d[k]["value"] = v
    else: d[k] = {"type": "generic", "value": v}
with open(cfg, "w") as f: json.dump(d, f, indent=4)
PY
  else
    warn "Menu: botão direito > Configurar > ícone personalizado > $ICON"
  fi
fi

# ----------------------------- 6. SPOTLIGHT ----------------------------------
if [[ "$INSTALAR_ULAUNCHER" == "1" ]]; then
  info "Instalando Ulauncher (busca estilo Spotlight — Ctrl+Espaço)"
  if sudo add-apt-repository -y ppa:agornostal/ulauncher && sudo apt update -y \
     && sudo apt install -y ulauncher; then
    cat > ~/.config/autostart/ulauncher.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Ulauncher
Exec=ulauncher --hide-window
X-GNOME-Autostart-enabled=true
EOF
    nohup ulauncher --hide-window >/dev/null 2>&1 &
  else
    warn "Ulauncher não instalado."
  fi
fi

# ----------------------------- 7. FINALIZA -----------------------------------
info "Reiniciando o Cinnamon para aplicar tudo"
dbus-send --session --dest=org.Cinnamon --type=method_call /org/Cinnamon \
  org.Cinnamon.Eval string:'global.reexec_self()' >/dev/null 2>&1 || true

echo
info "Pronto! Se algo não aparecer certinho, faça logout e login."
echo "   Backup das configs antigas: ~/mac-look-backup"
echo "   Para voltar ao visual anterior:"
echo "     dconf load /org/cinnamon/ < ~/mac-look-backup/cinnamon.dconf"
