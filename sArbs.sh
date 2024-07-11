#!/bin/sh
# 10.07.2024
# Sergi's Auto Rice Bootstrapping Script (SARBS)
# License: GNU GPLv3


#V# Benutzerbezogene Variablen ###
name="username"
logfile="/home/$name/installation_log.txt"
repodir="/home/$name/repositories"

#V# Systempfade und -verzeichnisse ###
aurhelper="yay"  # Beispiel für einen AUR-Helper
browserdir="/home/$name/.librewolf"
dotfilesrepo="https://github.com/sergi-us/viodrice.git"
progsfile="https://raw.githubusercontent.com/Sergi-us/SARBS/master/progs.csv"
repobranch="master"  # Standard-Branch für Git-Repositories
export TERM=ansi

# Alle Ausgaben und Fehler in die Logdatei umleiten
exec > >(tee -a "$logfile") 2>&1

# Funktion zum Schreiben von Lognachrichten
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

#TODO# Nutzerverzeichnisse anlegen
#- Dokumente
#- Musik
#- Downloads
#- Bilder
#- Bilder/Hintergrundbilder
#- Bilder/screenshots
#- Videos
#- Videos/screencast


### Blockspezifische Einträge ###

## für ~/.confi/newsboad/urls
rssurls="https://lukesmith.xyz/rss.xml
https://videos.lukesmith.xyz/feeds/videos.xml?videoChannelId=2 \"~Luke Smith (Videos)\"
https://www.youtube.com/feeds/videos.xml?channel_id=UC2eYFnH61tmytImy1mTYvhA \"~Luke Smith (YouTube)\"
https://lindypress.net/rss
https://notrelated.xyz/rss
https://landchad.net/rss.xml
https://based.cooking/index.xml
https://artixlinux.org/feed.php \"tech\"
https://www.archlinux.org/feeds/news/ \"tech\"
https://github.com/LukeSmithxyz/voidrice/commits/master.atom \"~SARBS dotfiles\""


# Aufruf der Funktion zum Löschen des Benutzerverzeichnisses
delete_user_directory



### FUNKTIONEN ###
log "Skript gestartet"

# Funktion zum Löschen des Benutzerverzeichnisses
delete_user_directory() {
    userdir="/home/$name"
    if [ -d "$userdir" ]; then
        log "Lösche Benutzerverzeichnis $userdir"
        rm -rf "$userdir"
        log "Benutzerverzeichnis $userdir gelöscht"
    else
        log "Benutzerverzeichnis $userdir existiert nicht"
    fi
}

#installpkg() {
#	pacman --noconfirm --needed -S "$1" >/dev/null 2>&1 || {
#	error "Stelle sicher, dass du das Skript als root-Benutzer ausführst, auf einer Arch-basierten Distribution bist und eine Internetverbindung hast."
#    }
#    log "Paket $1 installiert."
#}

error() {
	# Log to stderr and exit with failure.
	printf "%s\n" "$1" >&2
	exit 1
}

welcomemsg() {
	whiptail --title "Willkommen!" \
		--msgbox "Willkommen zum  Sergi's Auto-Rice Bootstrapping Script!\\n\\nDieses Skript wird eine Vollständige Desktopumgebung instalieren.\\n\\n-Sergius" 10 60

	whiptail --title "Wichtige Nachricht!" --yes-button "Bereit!" \
		--no-button "Enter..." \
		--yesno "stelle sicher dass du Arch aktualiert hast -pacman -Syu-.\\n\\nIf beachte das generierte Installationsprotokoll in deinem Home Verzeichniss." 8 70
}

getuserandpass() {
	# Prompts user for new username and password.
	name=$(whiptail --inputbox "Gib deinen neuen Benutzernamen ein." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
	while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
	        name=$(whiptail --nocancel --inputbox "Nutzername ungültig. Gib einen Benutzernamen ein, der mit einem Buchstaben beginnt und nur Kleinbuchstaben, - oder _ enthält." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(whiptail --nocancel --passwordbox "Gib ein Passwort für den Benutzer ein." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(whiptail --nocancel --passwordbox "Wiederhole das Passwort." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
	        pass1=$(whiptail --nocancel --passwordbox "Passwort stimmt nicht überein.\\n\\nGib das Passwort für den Benutzer ein." 10 60 3>&1 1>&2 2>&3 3>&1)
	        pass2=$(whiptail --nocancel --passwordbox "Wiederhole das Passwort." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
}

usercheck() {
	! { id -u "$name" >/dev/null 2>&1; } ||
		whiptail --title "WARNUNG" --yes-button "FORTFAHREN" \
			--no-button "Nein warte..." \
			--yesno "Der Nutzer \`$name\` existiert bereits auf diesem System. SARBS kann den Nutzer erstellen, es ÜBERSCHREIBT jedoch alle bestehenden Einstellungen und Nutzerdaten.\\n\\nSARBS wird AUCH deine Daten löschen (oder auch nicht, die Funktion ist noch in der Entwicklung, also verlasse dich nicht darauf. Entweder hast du das Skript angepasst oder du konfigurierst einen neuen Nutzer. Drücke <FORTFAHREN>, wenn du weißt, was du tust.\\n\\nBedenke auch, SARBS wird das Passwort von $name ändern zu dem, welches du gerade vergeben hast." 14 70
}

preinstallmsg() {
	whiptail --title "Let's get this party started!" --yes-button "Let's go!" \
		--no-button "Nee, lass ma!" \
	        --yesno "Der Rest der Installation läuft automatisch. Gönn dir ein Erfrischungsgetränk und relax.\\n\\nEs wird seine Zeit brauchen. Sobald der Installationsprozess abgeschlossen ist, hast du ein fertig konfiguriertes System.\\n\\nWenn du jetzt <Let's go!> drückst, beginnt die Installation!" 13 60 || {
		clear
		exit 1
	}
}

adduserandpass() {
	# Fügt den Benutzer `$name` mit dem Passwort $pass1 hinzu.
	whiptail --infobox "Benutzer \"$name\" wird hinzugefügt..." 7 50
	useradd -m -g wheel -s /bin/zsh "$name" >/dev/null 2>&1 || {
		usermod -a -G wheel "$name"
		mkdir -p /home/"$name"
		chown "$name":wheel /home/"$name"
	}
	# Setzt das Verzeichnis für Repositories
	export repodir="/home/$name/.local/src"
	mkdir -p "$repodir"
	chown -R "$name":wheel "$(dirname "$repodir")"
	# Setzt das Passwort für den Benutzer
	echo "$name:$pass1" | chpasswd
	# Löscht die Passworteingaben aus dem Speicher
	unset pass1 pass2
}

refreshkeys() {
    # Überprüft, welches Init-System verwendet wird.
    case "$(readlink -f /sbin/init)" in
    *systemd*)
        # Falls systemd verwendet wird, aktualisiere den Arch Keyring.
        whiptail --infobox "Aktualisiere Arch Keyring..." 7 40
        pacman --noconfirm -S archlinux-keyring >/dev/null 2>&1
        ;;
    *)
        # Falls ein anderes Init-System verwendet wird, aktiviere die Arch Repositories.
        whiptail --infobox "Aktiviere Arch Repositories für eine umfangreichere Softwareauswahl..." 7 40
        pacman --noconfirm --needed -S \
            artix-keyring artix-archlinux-support >/dev/null 2>&1
        grep -q "^\[extra\]" /etc/pacman.conf ||
            echo "[extra]
Include = /etc/pacman.d/mirrorlist-arch" >>/etc/pacman.conf
        pacman -Sy --noconfirm >/dev/null 2>&1
        pacman-key --populate archlinux >/dev/null 2>&1
        ;;
    esac
}
# Manuelle Installation von Paketen

manualinstall() {
    # Installiert $1 manuell. Wird hier nur für den AUR-Helper verwendet.
    # Sollte ausgeführt werden, nachdem `repodir` erstellt und die Variable gesetzt wurde.
    if pacman -Qq "$1" &>/dev/null; then
        return 0
    fi

    whiptail --infobox "Installiere \"$1\" manuell." 7 50

    # Erstellt das Verzeichnis für das Paket im Repositories-Verzeichnis
    sudo -u "$name" mkdir -p "$repodir/$1"
    if sudo -u "$name" git -C "$repodir" clone --depth 1 --single-branch --no-tags -q "https://aur.archlinux.org/$1.git" "$repodir/$1"; then
        cd "$repodir/$1" || return 1
    else
        cd "$repodir/$1" || return 1
        sudo -u "$name" git pull --force origin master || return 1
    fi

    # Baut und installiert das Paket
    sudo -u "$name" makepkg --noconfirm -si >/dev/null 2>&1 || return 1
}

# Funktion zum Installieren von Paketen über pacman
installpkg() {
    pacman --noconfirm --needed -S "$1" >/dev/null 2>&1 || {
        error "Stelle sicher, dass du das Skript als root-Benutzer ausführst, auf einer Arch-basierten Distribution bist und eine Internetverbindung hast."
    }
    log "Paket $1 installiert."
}

# Installiere Git über pacman
log "Installiere Git..."
installpkg git

# Manuelle Installation des AUR-Helpers (YAY oder Paru)
log "Installiere $aurhelper..."
manualinstall "$aurhelper"maininstall() {
    # Installs all needed programs from main repo.
    whiptail --title "SARBS Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 9 70
    installpkg "$1"
}

gitmakeinstall() {
    # Installiert ein Programm von einem Git-Repository und baut es mit `make`.
    progname="${1##*/}"
    progname="${progname%.git}"
    dir="$repodir/$progname"
    whiptail --title "SARBS Installation" \
        --infobox "Installiere \`$progname\` ($n von $total) via \`git\` und \`make\`. $(basename "$1") $2" 8 70

    # Klone das Repository, falls es nicht bereits existiert
    if sudo -u "$name" git -C "$repodir" clone --depth 1 --single-branch --no-tags -q "$1" "$dir"; then
        cd "$dir" || return 1
    else
        # Falls das Klonen fehlschlägt, wechsle in das Verzeichnis und versuche, es zu aktualisieren
        cd "$dir" || return 1
        sudo -u "$name" git pull --force origin master || return 1
    fi

    # Baue das Programm mit `make` und installiere es
    sudo -u "$name" make >/dev/null 2>&1 || return 1
    sudo make install >/dev/null 2>&1 || return 1
    cd /tmp || return 1
}

aurinstall() {
    # Installiert ein Paket aus dem AUR.
    whiptail --title "SARBS Installation" \
        --infobox "Installiere \`$1\` ($n von $total) aus dem AUR. $1 $2" 9 70

    # Überprüft, ob das Paket bereits installiert ist
    echo "$aurinstalled" | grep -q "^$1$" && return 1

    # Installiert das Paket mit dem AUR-Helper
    sudo -u "$name" $aurhelper -S --noconfirm "$1" >/dev/null 2>&1 || return 1
}

pipinstall() {
    # Installiert ein Python-Paket mit pip.
    whiptail --title "SARBS Installation" \
        --infobox "Installiere das Python-Paket \`$1\` ($n von $total). $1 $2" 9 70

    # Überprüft, ob pip installiert ist, und installiert es falls notwendig
    [ -x "$(command -v "pip")" ] || installpkg python-pip >/dev/null 2>&1 || return 1

    # Installiert das Python-Paket mit pip
    yes | pip install "$1" >/dev/null 2>&1 || return 1
}


installationloop() {
    n=0
    tmpfile=$(mktemp /tmp/progs.csv.XXXXXX)

    # Überprüfen, ob die Programmliste lokal vorhanden ist, andernfalls herunterladen
    if [ -f "$progsfile" ]; then
        cp "$progsfile" "$tmpfile" || { echo "Kopieren von $progsfile fehlgeschlagen"; return 1; }
    else
        curl -Ls "$progsfile" | sed '/^#/d' >"$tmpfile" || { echo "Herunterladen von $progsfile fehlgeschlagen"; return 1; }
    fi

    total=$(wc -l <"$tmpfile")
    aurinstalled=$(pacman -Qqm)

    # Lesen der Programmliste und Installation entsprechend des Tags
    while IFS=, read -r tag program comment; do
        n=$((n + 1))
        echo "$comment" | grep -q "^\".*\"$" &&
            comment="$(echo "$comment" | sed -E "s/(^\"|\"$)//g")"
        case "$tag" in
        "A") aurinstall "$program" "$comment" ;;
        "G") gitmakeinstall "$program" "$comment" ;;
        "P") pipinstall "$program" "$comment" ;;
        *) maininstall "$program" "$comment" ;;
        esac
    done <"$tmpfile"

    rm -f "$tmpfile"
}

putgitrepo() {
    # Lädt ein Git-Repository $1 herunter und platziert die Dateien in $2, wobei nur Konflikte überschrieben werden
    whiptail --infobox "Lade Konfigurationsdateien herunter und installiere sie..." 7 60
    branch=${3:-master}
    dir=$(mktemp -d)
    [ ! -d "$2" ] && mkdir -p "$2"
    chown "$name:wheel" "$dir" "$2"

    # Klont das Repository in das temporäre Verzeichnis
    if sudo -u "$name" git -C "$repodir" clone --depth 1 \
        --single-branch --no-tags -q --recursive -b "$branch" \
        --recurse-submodules "$1" "$dir"; then
        # Kopiert die Dateien vom temporären Verzeichnis in das Zielverzeichnis
        sudo -u "$name" cp -rfT "$dir" "$2" || { echo "Kopieren der Dateien fehlgeschlagen"; log "Kopieren der Dateien fehlgeschlagen"; return 1; }
    else
        echo "Klonen des Repositorys fehlgeschlagen"
        log "Klonen des Repositorys fehlgeschlagen"
        return 1
    fi

    # Löscht das temporäre Verzeichnis
    rm -rf "$dir"
    log "Konfigurationsdateien erfolgreich heruntergeladen und installiert"
}

vimplugininstall() {
    # Installiert vim Plugins.
    whiptail --infobox "Installiere neovim Plugins..." 7 60

    # Erstellt das Verzeichnis für vim Plug, falls es nicht existiert
    mkdir -p "/home/$name/.config/nvim/autoload"

    # Lädt vim Plug herunter und speichert es im autoload-Verzeichnis
    curl -Ls "https://raw.githubusercontent.com/Sergi-us/vim-plug/master/plug.vim" > "/home/$name/.config/nvim/autoload/plug.vim"

    # Setzt die richtigen Eigentümerrechte für das nvim Konfigurationsverzeichnis
    chown -R "$name:wheel" "/home/$name/.config/nvim"

    # Installiert die Plugins mit nvim und schließt nvim automatisch
    sudo -u "$name" nvim -c "PlugInstall|q|q"
}

makeuserjs() {
    # Holt die Arkenfox user.js und bereitet sie vor.
    arkenfox="$pdir/arkenfox.js"
    overrides="/home/$name/.config/firefox/larbs.js"
    userjs="$pdir/user.js"

    # Erstellt einen symbolischen Link zu den User-Overrides
    ln -fs "$overrides" "$pdir/user-overrides.js"

    # Lädt die Arkenfox user.js herunter, falls sie nicht existiert
    if [ ! -f "$arkenfox" ]; then
        curl -sL "https://raw.githubusercontent.com/arkenfox/user.js/master/user.js" > "$arkenfox"
    fi

    # Kombiniert die Arkenfox user.js und die User-Overrides zu einer neuen user.js
    cat "$arkenfox" "$pdir/user-overrides.js" > "$userjs"
    chown "$name:wheel" "$arkenfox" "$userjs"

    # Installiert das Update-Skript.
    mkdir -p /usr/local/lib /etc/pacman.d/hooks
    cp "/home/$name/.local/bin/arkenfox-auto-update" /usr/local/lib/
    chown root:root /usr/local/lib/arkenfox-auto-update
    chmod 755 /usr/local/lib/arkenfox-auto-update

    # Richtet einen pacman-Hook ein, um das Update bei Bedarf auszulösen.
    echo "[Trigger]
Operation = Upgrade
Type = Package
Target = firefox
Target = librewolf
Target = librewolf-bin
[Action]
Description = Update Arkenfox user.js
When = PostTransaction
Depends = arkenfox-user.js
Exec = /usr/local/lib/arkenfox-auto-update" > /etc/pacman.d/hooks/arkenfox.hook
}

installffaddons() {
    # Liste der Firefox-Addons
    addonlist="ublock-origin decentraleyes istilldontcareaboutcookies vim-vixen keepassxc-browser"
    addontmp="$(mktemp -d)"
    trap "rm -fr $addontmp" HUP INT QUIT TERM PWR EXIT
    IFS=' '

    # Erstellen des Verzeichnisses für die Addons
    sudo -u "$name" mkdir -p "$pdir/extensions/"

    for addon in $addonlist; do
        if [ "$addon" = "ublock-origin" ]; then
            # Spezielle URL für uBlock Origin
            addonurl="$(curl -sL https://api.github.com/repos/gorhill/uBlock/releases/latest | grep -E 'browser_download_url.*\.firefox\.xpi' | cut -d '"' -f 4)"
        elif [ "$addon" = "keepassxc-browser" ]; then
            # Spezielle URL für KeePassXC-Browser
            addonurl="https://addons.mozilla.org/firefox/downloads/file/3597426/keepassxc_browser-1.8.7.xpi"
        else
            # Allgemeine URL für andere Addons
            addonurl="$(curl --silent "https://addons.mozilla.org/en-US/firefox/addon/${addon}/" | grep -o 'https://addons.mozilla.org/firefox/downloads/file/[^"]*')"
        fi

        file="${addonurl##*/}"
        sudo -u "$name" curl -LOs "$addonurl" -o "$addontmp/$file"

        # Extrahiert die ID aus der manifest.json
        id="$(unzip -p "$addontmp/$file" manifest.json | grep "\"id\"")"
        id="${id%\"*}"
        id="${id##*\"}"

        mv "$addontmp/$file" "$pdir/extensions/$id.xpi"
    done

    chown -R "$name:$name" "$pdir/extensions"

    # Behebt einen Vim Vixen Bug mit dem Dunkelmodus
    if [ ! -d "$pdir/chrome" ]; then
        sudo -u "$name" mkdir -p "$pdir/chrome"
    fi

    if [ ! -f "$pdir/chrome/userContent.css" ]; then
        echo ".vimvixen-console-frame { color-scheme: light !important; }
#category-more-from-mozilla { display: none !important }" > "$pdir/chrome/userContent.css"
    fi
}

finalize() {
    # Zeigt eine Nachricht an, dass der Installationsprozess abgeschlossen ist
    whiptail --title "Alles erledigt!" \
        --msgbox "Herzlichen Glückwunsch! Vorausgesetzt, es gab keine versteckten Fehler, wurde das Skript erfolgreich abgeschlossen und alle Programme und Konfigurationsdateien sollten vorhanden sein.\\n\\nUm die neue grafische Umgebung zu starten, melde dich ab und wieder als dein neuer Benutzer an, und führe dann den Befehl \"startx\" aus, um die grafische Umgebung zu starten (sie wird automatisch in tty1 gestartet).\\n\\n.t Sergius" 13 80
}


### THE ACTUAL SCRIPT ###

### This is how everything happens in an intuitive format and order.

### Automatisierter Bereich

# Aktualisiert die Arch Keyrings.
refreshkeys || error "Fehler beim automatischen Aktualisieren des Arch Keyrings. Bitte manuell aktualisieren."

for x in curl ca-certificates base-devel git ntp zsh; do
    whiptail --title "SARBS Installation" \
        --infobox "Installiere \`$x\`, das benötigt wird, um andere Programme zu installieren und zu konfigurieren." 8 70
    installpkg "$x"
done

whiptail --title "SARBS Installation" \
    --infobox "Synchronisiere Systemzeit, um eine erfolgreiche und sichere Installation von Software zu gewährleisten..." 8 70
ntpd -q -g >/dev/null 2>&1

adduserandpass || error "Fehler beim Hinzufügen von Benutzername und/oder Passwort."

[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # Nur für den Fall

# Erlaubt dem Benutzer, sudo ohne Passwort auszuführen.
# Da AUR-Programme in einer fakeroot-Umgebung installiert werden müssen, ist dies für alle Builds mit AUR erforderlich.
trap 'rm -f /etc/sudoers.d/larbs-temp' HUP INT QUIT TERM PWR EXIT
echo "%wheel ALL=(ALL) NOPASSWD: ALL
Defaults:%wheel,root runcwd=*" >/etc/sudoers.d/larbs-temp

# Macht pacman bunt, ermöglicht gleichzeitige Downloads und fügt Pacman Eye-Candy hinzu.
grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
sed -Ei "s/^#(ParallelDownloads).*/\1 = 5/;/^#Color$/s/#//" /etc/pacman.conf

# Nutzt alle Kerne für die Kompilierung.
sed -i "s/-j2/-j$(nproc)/;/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf

# Achtung bezieht sich auf manualinstall im Bereich 168 und 188...
manualinstall "$aurhelper" || error "Fehler bei der Installation des AUR-Helpers."

# Stellt sicher, dass .*-git AUR-Pakete automatisch aktualisiert werden.
$aurhelper -Y --save --devel

# Der Befehl, der alle Programme installiert. Liest die progs.csv-Datei und
# installiert jedes benötigte Programm auf die erforderliche Weise.
# Stellen Sie sicher, dass dies nur ausgeführt wird, nachdem der Benutzer erstellt wurde und die Berechtigung hat,
# sudo ohne Passwort auszuführen und alle Build-Abhängigkeiten installiert sind.
installationloop

# Installiert die Dotfiles im Home-Verzeichnis des Benutzers, entfernt jedoch das .git-Verzeichnis und
# andere unnötige Dateien.
putgitrepo "$dotfilesrepo" "/home/$name" "$repobranch"
[ -z "/home/$name/.config/newsboat/urls" ] && echo "$rssurls" > "/home/$name/.config/newsboat/urls"
log "Newsboat-URLs konfiguriert"
rm -rf "/home/$name/.git/" "/home/$name/README.md" "/home/$name/LICENSE" "/home/$name/FUNDING.yml"
log "Überflüssige Dateien entfernt"

# Installiert vim-Plugins, wenn sie noch nicht vorhanden sind.
[ ! -f "/home/$name/.config/nvim/autoload/plug.vim" ] && vimplugininstall

# Wichtigster Befehl! Schaltet den Piepton aus!
rmmod pcspkr
echo "blacklist pcspkr" >/etc/modprobe.d/nobeep.conf

# Setzt zsh als Standardshell für den Benutzer.
chsh -s /bin/zsh "$name" >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"
sudo -u "$name" mkdir -p "/home/$name/.config/abook/"
sudo -u "$name" mkdir -p "/home/$name/.config/mpd/playlists/"

# D-Bus UUID muss für Artix runit generiert werden.
dbus-uuidgen >/var/lib/dbus/machine-id

# Nutzt Systembenachrichtigungen für Brave auf Artix.
echo "export \$(dbus-launch)" >/etc/profile.d/dbus.sh

# Aktiviert Tap-to-Click.
[ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && printf 'Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
	# Enable left mouse button by tapping
	Option "Tapping" "on"
EndSection' >/etc/X11/xorg.conf.d/40-libinput.conf

whiptail --infobox "Setze Browser-Datenschutzeinstellungen und Add-Ons..." 7 60
log "Browser-Datenschutzeinstellungen und Add-Ons werden gesetzt"

browserdir="/home/$name/.librewolf"
profilesini="$browserdir/profiles.ini"

# Startet LibreWolf im Headless-Modus, um ein Profil zu erstellen, und holt dann dieses Profil in eine Variable.
log "Starte LibreWolf im Headless-Modus, um ein Profil zu erstellen"
sudo -u "$name" librewolf --headless >/dev/null 2>&1 &
sleep 5  # Wartet etwas länger, um sicherzustellen, dass das Profil erstellt wird
profile="$(sed -n "/Default=.*.default-default/ s/.*=//p" "$profilesini")"
pdir="$browserdir/$profile"
log "Profilverzeichnis: $pdir"

# Überprüft, ob das Profilverzeichnis existiert, und führt die Funktionen aus
if [ -d "$pdir" ]; then
    log "Profilverzeichnis existiert, führe makeuserjs und installffaddons aus"
    makeuserjs
    installffaddons
else
    log "Profilverzeichnis existiert nicht, überspringe makeuserjs und installffaddons"
fi

# Beendet die nun unnötige LibreWolf-Instanz.
log "Beende die LibreWolf-Instanz"
pkill -u "$name" librewolf

# Erlaubt Benutzern der Gruppe wheel, sudo mit Passwort auszuführen und erlaubt mehrere Systembefehle
# (wie `shutdown`) ohne Passwort auszuführen.
log "Konfiguriere Sudoers-Dateien"
echo "%wheel ALL=(ALL:ALL) ALL" >/etc/sudoers.d/00-larbs-wheel-can-sudo
echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/shutdown, /usr/bin/reboot, /usr/bin/systemctl suspend, /usr/bin/wifi-menu, /usr/bin/mount, /usr/bin/umount, /usr/bin/pacman -Syu, /usr/bin/pacman -Syyu, /usr/bin/pacman -Syyu --noconfirm, /usr/bin/loadkeys, /usr/bin/pacman -Syyuw --noconfirm, /usr/bin/pacman -S -y --config /etc/pacman.conf --, /usr/bin/pacman -S -y -u --config /etc/pacman.conf --" >/etc/sudoers.d/01-larbs-cmds-without-password
echo "Defaults editor=/usr/bin/nvim" >/etc/sudoers.d/02-larbs-visudo-editor

# Erlaubt dmesg für alle Benutzer
log "Setze dmesg-Berechtigungen für alle Benutzer"
mkdir -p /etc/sysctl.d
echo "kernel.dmesg_restrict = 0" > /etc/sysctl.d/dmesg.conf

# Bereinigt temporäre Sudoers-Dateien
log "Bereinige temporäre Sudoers-Dateien"
rm -f /etc/sudoers.d/larbs-temp

# Letzte Nachricht! Installation abgeschlossen!
log "Installation abgeschlossen"
finalize
