#!/usr/bin/env bash
# =============================================================================
#  mac-ajuste.sh — Alterna o visual entre CLARO e ESCURO (após o instalador)
#
#   light → tema claro, barra de menus clara, maçã preta, wallpaper 4K claro
#   dark  → tema escuro, barra de menus preta, maçã branca, wallpaper 4K escuro
#
#  Uso:  ./mac-ajuste.sh light     ou     ./mac-ajuste.sh dark     (sem sudo)
# =============================================================================
set -uo pipefail

# Papéis de parede 4K de cada modo (opções em assets/wallpapers-*.jpg):
#   claro:  Sonoma-light | Ventura-light | Monterey-light | WhiteSur-light
#   escuro: Sonoma-dark  | Ventura-dark  | Monterey-dark  | WhiteSur-dark
PAPEL_LIGHT="Sonoma-light"
PAPEL_DARK="Sonoma-dark"

MODO="${1:-light}"
VERDE='\e[32m'; AMARELO='\e[33m'; NC='\e[0m'
info() { echo -e "${VERDE}==>${NC} $*"; }
warn() { echo -e "${AMARELO}[aviso]${NC} $*"; }
[[ $EUID -eq 0 ]] && { echo "Não use sudo."; exit 1; }

case "$MODO" in
  light) GTK="WhiteSur-Light"; ICONES="WhiteSur-light"; PAPEL="$PAPEL_LIGHT"
         MACA="activities-black" ;;   # maçã preta para barra clara
  dark)  GTK="WhiteSur-Dark";  ICONES="WhiteSur-dark";  PAPEL="$PAPEL_DARK"
         MACA="activities" ;;         # maçã branca para barra preta
  *) echo "Uso: $0 light|dark"; exit 1 ;;
esac

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
info "Baixando recursos do tema WhiteSur"
git clone --depth=1 -q https://github.com/vinceliuice/WhiteSur-gtk-theme.git "$TMP/ws" \
  || { warn "Falha ao baixar o tema. Verifique a internet."; exit 1; }

# Garante que a variante pedida está instalada
[[ -d ~/.themes/$GTK ]] || ( cd "$TMP/ws" && yes | ./install.sh -c "$MODO" -l )

# --------------------------------- TEMA --------------------------------------
info "Aplicando tema $MODO"
gsettings set org.cinnamon.desktop.interface gtk-theme  "$GTK"
gsettings set org.cinnamon.desktop.interface icon-theme "$ICONES"
gsettings set org.cinnamon.desktop.wm.preferences theme "$GTK"
gsettings set org.cinnamon.theme name                   "$GTK"
gsettings set org.gnome.desktop.interface gtk-theme     "$GTK"    2>/dev/null
gsettings set org.gnome.desktop.interface icon-theme    "$ICONES" 2>/dev/null
gsettings set org.gnome.desktop.interface color-scheme  "prefer-$MODO" 2>/dev/null

# ---------------------------- PAPEL DE PAREDE 4K -----------------------------
info "Baixando papéis de parede 4K (Sonoma, Ventura, Monterey, Big Sur)"
WDIR="$( [[ -d ~/Imagens ]] && echo ~/Imagens || echo ~/Pictures )/Wallpapers-Mac"
mkdir -p "$WDIR"
if git clone --depth=1 -q https://github.com/vinceliuice/WhiteSur-wallpapers.git "$TMP/wp"; then
  cp -f "$TMP/wp/4k/"*.jpg "$WDIR"/
fi
W="$WDIR/${PAPEL}.jpg"
[[ -f "$W" ]] || W="$(find "$WDIR" -iname "*${MODO}*" | head -n1)"
if [[ -n "$W" && -f "$W" ]]; then
  gsettings set org.cinnamon.desktop.background picture-uri "file://$W"
  gsettings set org.cinnamon.desktop.background picture-options 'zoom'
  info "Papel de parede: $(basename "$W")  (outros em $WDIR)"
fi

# --------------------------------- DOCK --------------------------------------
NOME_PLANK="WhiteSur-${GTK#WhiteSur-}"
SRC_PLANK="$TMP/ws/other/plank/theme-${GTK#WhiteSur-}"
mkdir -p ~/.local/share/plank/themes
if [[ -d "$SRC_PLANK" ]]; then
  rm -rf ~/.local/share/plank/themes/"$NOME_PLANK"
  cp -r "$SRC_PLANK" ~/.local/share/plank/themes/"$NOME_PLANK"
  gsettings set net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/ theme "$NOME_PLANK"
fi

# --------------------------- ÍCONE DA MAÇÃ NO MENU ---------------------------
info "Aplicando a maçã no menu ($( [[ $MODO == dark ]] && echo branca || echo preta ))"
mkdir -p ~/.local/share/icons/mac-menu
ICON=~/.local/share/icons/mac-menu/apple-menu-$MODO.svg
cp "$TMP/ws/src/assets/gnome-shell/$MACA/activities-apple.svg" "$ICON"

CFG="$(ls ~/.config/cinnamon/spices/menu@cinnamon.org/*.json 2>/dev/null | head -n1)"
if [[ -n "$CFG" ]]; then
  cp "$CFG" "$CFG.bak"
  python3 - "$CFG" "$ICON" <<'PY'
import json, sys
cfg, icon = sys.argv[1], sys.argv[2]
with open(cfg) as f: d = json.load(f)
def setv(k, v):
    if k in d and isinstance(d[k], dict): d[k]["value"] = v
    else: d[k] = {"type": "generic", "value": v}
setv("menu-custom", True)
setv("menu-icon", icon)
setv("menu-label", "")
with open(cfg, "w") as f: json.dump(d, f, indent=4)
PY
else
  warn "Configuração do menu não encontrada. Botão direito no menu > Configurar >"
  warn "'Usar ícone personalizado' e escolha: $ICON"
fi

# ------------------------------- RECARREGA -----------------------------------
info "Recarregando o Cinnamon e o dock"
pkill -x plank 2>/dev/null; sleep 1; nohup plank >/dev/null 2>&1 &
dbus-send --session --dest=org.Cinnamon --type=method_call /org/Cinnamon \
  org.Cinnamon.Eval string:'global.reexec_self()' >/dev/null 2>&1 || true
info "Pronto! Visual $MODO aplicado. Se algo não mudar, faça logout e login."
