#!/bin/sh

# 11.06.2024 0.9 Prelaunch Version
# Sergi's automatisches Einrichtungsskript (SARBS)
# von Luke Smith <luke@lukesmith.xyz>
# übersetzt von Sergius <sergius@posteo.de>
# Lizenz: GNU GPLv3

### OPTIONEN UND VARIABLEN ###

dotfilesrepo="https://github.com/Sergi-us/voidrice.git"
progsfile="https://raw.githubusercontent.com/Sergi-us/SARBS/master/progs.csv"
aurhelper="yay"
repobranch="master"
export TERM=ansi

rssurls="https://lukesmith.xyz/rss.xml
https://videos.lukesmith.xyz/feeds/videos.xml?videoChannelId=2 \"~Luke Smith (Videos)\"
https://www.youtube.com/feeds/videos.xml?channel_id=UC2eYFnH61tmytImy1mTYvhA \"~Luke Smith (YouTube)\"
https://notrelated.xyz/rss
https://based.cooking/index.xml
https://artixlinux.org/feed.php \"tech\"
https://www.archlinux.org/feeds/news/ \"tech\"
https://github.com/Sergi-US/voidrice/commits/master.atom \"~SARBS dotfiles\""

### FUNKTIONEN ###

installpkg() {
	pacman --noconfirm --needed -S "$1" >/dev/null 2>&1
}

error() {
	# Ausgabe in stderr und Beenden mit Fehler.
	printf "%s\n" "$1" >&2
	exit 1
}

welcomemsg() {
	whiptail --title "Willkommen!" \
		--msgbox "Willkommen bei SARBS automatischem Einrichtungsskript!\\n\\nDieses Skript installiert automatisch einen voll ausgestatteten Linux-Desktop, den ich als mein Hauptsystem verwende.\\n\\n-Sergius" 10 60

	whiptail --title "Wichtiger Hinweis!" --yes-button "Alles bereit!" \
		--no-button "Zurück..." \
		--yesno "Stelle sicher, dass der Computer, den du verwendest, aktuelle pacman-Updates und aktualisierte Arch-Schlüsselringe hat.\\n\\nFalls nicht, kann die Installation einiger Programme fehlschlagen." 8 70
}

getuserandpass() {
	# Fragt den Benutzer nach einem neuen Benutzernamen und Passwort.
	name=$(whiptail --inputbox "Bitte gib zuerst einen Namen für das Benutzerkonto ein." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
	while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
		name=$(whiptail --nocancel --inputbox "Ungültiger Benutzername. Gib einen Benutzernamen ein, der mit einem Buchstaben beginnt und nur Kleinbuchstaben, - oder _ enthält." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(whiptail --nocancel --passwordbox "Gib ein Passwort für diesen Benutzer ein." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(whiptail --nocancel --passwordbox "Wiederhole das Passwort." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		pass1=$(whiptail --nocancel --passwordbox "Passwörter stimmen nicht überein.\\n\\nGib das Passwort erneut ein." 10 60 3>&1 1>&2 2>&3 3>&1)
		pass2=$(whiptail --nocancel --passwordbox "Wiederhole das Passwort." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
}

usercheck() {
	! { id -u "$name" >/dev/null 2>&1; } ||
		whiptail --title "WARNUNG" --yes-button "FORTFAHREN" \
			--no-button "Nein, warte..." \
			--yesno "Der Benutzer \`$name\` existiert bereits auf diesem System. SARBS kann für einen bereits existierenden Benutzer installieren, aber es wird alle konfliktierenden Einstellungen/Dotfiles des Benutzerkontos ÜBERSCHREIBEN.\\n\\nSARBS wird deine Benutzerdaten, Dokumente, Videos usw. NICHT überschreiben, also mach dir darum keine Sorgen, aber klicke nur auf <FORTFAHREN>, wenn du damit einverstanden bist, dass deine Einstellungen überschrieben werden.\\n\\nBeachte auch, dass SARBS das Passwort von $name auf das von dir eingegebene ändern wird." 14 70
}

preinstallmsg() {
	whiptail --title "Lass uns anfangen!" --yes-button "Los geht's!" \
		--no-button "Nein, doch nicht!" \
		--yesno "Der Rest der Installation wird jetzt völlig automatisiert ablaufen, sodass du dich zurücklehnen und entspannen kannst.\\n\\nEs wird einige Zeit dauern, aber wenn es fertig ist, kannst du dich noch mehr entspannen mit deinem kompletten System.\\n\\nDrücke jetzt einfach <Los geht's!> und die Installation wird beginnen!" 13 60 || {
		clear
		exit 1
	}
}

adduserandpass() {
	# Fügt den Benutzer `$name` mit dem Passwort $pass1 hinzu.
	whiptail --infobox "Benutzer \"$name\" wird hinzugefügt..." 7 50
	useradd -m -g wheel -s /bin/zsh "$name" >/dev/null 2>&1 ||
		usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
	export repodir="/home/$name/.local/src"
	mkdir -p "$repodir"
	chown -R "$name":wheel "$(dirname "$repodir")"
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2
}

refreshkeys() {
	case "$(readlink -f /sbin/init)" in
	*systemd*)
		whiptail --infobox "Arch-Schlüsselring wird aktualisiert..." 7 40
		pacman --noconfirm -S archlinux-keyring >/dev/null 2>&1
		;;
	*)
		whiptail --infobox "Aktivierung der Arch-Repositories für eine umfangreichere Softwareauswahl..." 7 40
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

manualinstall() {
	# Installiert $1 manuell. Wird hier nur für den AUR-Helper verwendet.
	# Sollte nach der Erstellung von repodir und der Setzung der Variable ausgeführt werden.
	pacman -Qq "$1" && return 0
	whiptail --infobox "\"$1\" wird manuell installiert." 7 50
	sudo -u "$name" mkdir -p "$repodir/$1"
	sudo -u "$name" git -C "$repodir" clone --depth 1 --single-branch \
		--no-tags -q "https://aur.archlinux.org/$1.git" "$repodir/$1" ||
		{
			cd "$repodir/$1" || return 1
			sudo -u "$name" git pull --force origin master
		}
	cd "$repodir/$1" || exit 1
	sudo -u "$name" -D "$repodir/$1" \
		makepkg --noconfirm -si >/dev/null 2>&1 || return 1
}

maininstall() {
	# Installiert alle benötigten Programme aus dem Hauptrepository.
	whiptail --title "SARBS Installation" --infobox "\`$1\` wird installiert ($n von $total). $1 $2" 9 70
	installpkg "$1"
}

gitmakeinstall() {
	progname="${1##*/}"
	progname="${progname%.git}"
	dir="$repodir/$progname"
	whiptail --title "SARBS Installation" \
		--infobox "\`$progname\` wird installiert ($n von $total) via \`git\` und \`make\`. $(basename "$1") $2" 8 70
	sudo -u "$name" git -C "$repodir" clone --depth 1 --single-branch \
		--no-tags -q "$1" "$dir" ||
		{
			cd "$dir" || return 1
			sudo -u "$name" git pull --force origin master
		}
	cd "$dir" || exit 1
	make >/dev/null 2>&1
	make install >/dev/null 2>&1
	cd /tmp || return 1
}

aurinstall() {
	whiptail --title "SARBS Installation" \
		--infobox "\`$1\` wird aus dem AUR installiert ($n von $total). $1 $2" 9 70
	echo "$aurinstalled" | grep -q "^$1$" && return 1
	sudo -u "$name" $aurhelper -S --noconfirm "$1" >/dev/null 2>&1
}

pipinstall() {
	whiptail --title "SARBS Installation" \
		--infobox "Das Python-Paket \`$1\` wird installiert ($n von $total). $1 $2" 9 70
	[ -x "$(command -v "pip")" ] || installpkg python-pip >/dev/null 2>&1
	yes | pip install "$1"
}

installationloop() {
	([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) ||
		curl -Ls "$progsfile" | sed '/^#/d' >/tmp/progs.csv
	total=$(wc -l </tmp/progs.csv)
	aurinstalled=$(pacman -Qqm)
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
	done </tmp/progs.csv
}

putgitrepo() {
	# Lädt ein Git-Repository $1 herunter und platziert die Dateien in $2, wobei nur Konflikte überschrieben werden
	whiptail --infobox "Konfigurationsdateien werden heruntergeladen und installiert..." 7 60
	[ -z "$3" ] && branch="master" || branch="$repobranch"
	dir=$(mktemp -d)
	[ ! -d "$2" ] && mkdir -p "$2"
	chown "$name":wheel "$dir" "$2"
	sudo -u "$name" git -C "$repodir" clone --depth 1 \
		--single-branch --no-tags -q --recursive -b "$branch" \
		--recurse-submodules "$1" "$dir"
	sudo -u "$name" cp -rfT "$dir" "$2"
}

vimplugininstall() {
	# Installiert vim-Plugins.
	whiptail --infobox "Neovim-Plugins werden installiert..." 7 60
	mkdir -p "/home/$name/.config/nvim/autoload"
	curl -Ls "https://raw.githubusercontent.com/Sergi-US/vim-plug/master/plug.vim" > "/home/$name/.config/nvim/autoload/plug.vim"
	chown -R "$name:wheel" "/home/$name/.config/nvim"
	sudo -u "$name" nvim -c "PlugInstall|q|q"
}

makeuserjs(){
	# Holen Sie sich die Arkenfox user.js und bereiten Sie sie vor.
	arkenfox="$pdir/arkenfox.js"
	overrides="$pdir/user-overrides.js"
	userjs="$pdir/user.js"
	ln -fs "/home/$name/.config/firefox/larbs.js" "$overrides"
	[ ! -f "$arkenfox" ] && curl -sL "https://raw.githubusercontent.com/Sergi-us/user.js/master/user.js" > "$arkenfox"
	cat "$arkenfox" "$overrides" > "$userjs"
	chown "$name:wheel" "$arkenfox" "$userjs"
	# Installieren des Aktualisierungsskripts.
	mkdir -p /usr/local/lib /etc/pacman.d/hooks
	cp "/home/$name/.local/bin/arkenfox-auto-update" /usr/local/lib/
	chown root:root /usr/local/lib/arkenfox-auto-update
	chmod 755 /usr/local/lib/arkenfox-auto-update
	# Auslösen des Updates bei Bedarf über einen pacman-Hook.
	echo "[Trigger]
Operation = Upgrade
Type = Package
Target = firefox
Target = librewolf
Target = librewolf-bin
[Action]
Description=Arkenfox user.js aktualisieren
When=PostTransaction
Depends=arkenfox-user.js
Exec=/usr/local/lib/arkenfox-auto-update" > /etc/pacman.d/hooks/arkenfox.hook
}

installffaddons(){
	addonlist="ublock-origin decentraleyes istilldontcareaboutcookies vim-vixen"
	addontmp="$(mktemp -d)"
	trap "rm -fr $addontmp" HUP INT QUIT TERM PWR EXIT
	IFS=' '
	sudo -u "$name" mkdir -p "$pdir/extensions/"
	for addon in $addonlist; do
		if [ "$addon" = "ublock-origin" ]; then
			addonurl="$(curl -sL https://api.github.com/repos/gorhill/uBlock/releases/latest | grep -E 'browser_download_url.*\.firefox\.xpi' | cut -d '"' -f 4)"
		else
			addonurl="$(curl --silent "https://addons.mozilla.org/en-US/firefox/addon/${addon}/" | grep -o 'https://addons.mozilla.org/firefox/downloads/file/[^"]*')"
		fi
		file="${addonurl##*/}"
		sudo -u "$name" curl -LOs "$addonurl" > "$addontmp/$file"
		id="$(unzip -p "$file" manifest.json | grep "\"id\"")"
		id="${id%\"*}"
		id="${id##*\"}"
		mv "$file" "$pdir/extensions/$id.xpi"
	done
	chown -R "$name:$name" "$pdir/extensions"
	# Behebung eines Bugs bei Vim Vixen mit dem Dunkelmodus, der im Upstream nicht behoben ist:
	sudo -u "$name" mkdir -p "$pdir/chrome"
	[ ! -f  "$pdir/chrome/userContent.css" ] && sudo -u "$name" echo ".vimvixen-console-frame { color-scheme: light !important; }
#category-more-from-mozilla { display: none !important }" > "$pdir/chrome/userContent.css"
}

finalize() {
	whiptail --title "Alles erledigt!" \
		--msgbox "Glückwunsch! Sofern keine versteckten Fehler aufgetreten sind, wurde das Skript erfolgreich abgeschlossen und alle Programme und Konfigurationsdateien sollten an ihrem Platz sein.\\n\\nUm die neue grafische Umgebung zu starten, melde dich ab und wieder als dein neuer Benutzer an, und führe dann den Befehl \"startx\" aus, um die grafische Umgebung zu starten (sie wird automatisch in tty1 gestartet).\\n\\n.t Luke" 13 80
}

### DAS EIGENTLICHE SKRIPT ###

### So läuft alles in einem intuitiven Format und einer intuitiven Reihenfolge ab.

# Überprüfen, ob der Benutzer root auf einem Arch-basierten System ist. Installiere whiptail.
pacman --noconfirm --needed -Sy libnewt ||
	error "Bist du sicher, dass du als root-Benutzer angemeldet bist, ein Arch-basiertes System verwendest und eine Internetverbindung hast?"

# Begrüße den Benutzer und wähle dotfiles aus.
welcomemsg || error "Benutzer hat abgebrochen."

# Benutzername und Passwort abfragen und überprüfen.
getuserandpass || error "Benutzer hat abgebrochen."

# Warnung geben, falls der Benutzer bereits existiert.
usercheck || error "Benutzer hat abgebrochen."

# Letzte Chance für den Benutzer, bevor die Installation beginnt.
preinstallmsg || error "Benutzer hat abgebrochen."

### Der Rest des Skripts erfordert keine Benutzereingabe mehr.

# Arch-Schlüsselringe aktualisieren.
refreshkeys ||
	error "Fehler beim automatischen Aktualisieren des Arch-Schlüsselrings. Versuche es manuell."

for x in curl ca-certificates base-devel git ntp zsh; do
	whiptail --title "SARBS Installation" \
		--infobox "\`$x\` wird installiert, das zur Installation und Konfiguration anderer Programme benötigt wird." 8 70
	installpkg "$x"
done

whiptail --title "SARBS Installation" \
	--infobox "Systemzeit synchronisieren, um eine erfolgreiche und sichere Installation der Software zu gewährleisten..." 8 70
ntpd -q -g >/dev/null 2>&1

adduserandpass || error "Fehler beim Hinzufügen des Benutzernamens und/oder Passworts."

[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # Nur für den Fall

# Erlaubt dem Benutzer, sudo ohne Passwort auszuführen. Da AUR-Programme in einer fakeroot-Umgebung installiert werden müssen, ist dies für alle Builds mit AUR erforderlich.
trap 'rm -f /etc/sudoers.d/larbs-temp' HUP INT QUIT TERM PWR EXIT
echo "%wheel ALL=(ALL) NOPASSWD: ALL
Defaults:%wheel,root runcwd=*" >/etc/sudoers.d/larbs-temp

# Machen Sie pacman farbenfroh, ermöglichen Sie gleichzeitige Downloads und fügen Sie Pacman-Optik hinzu.
grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
sed -Ei "s/^#(ParallelDownloads).*/\1 = 5/;/^#Color$/s/#//" /etc/pacman.conf

# Verwenden Sie alle Kerne für die Kompilierung.
sed -i "s/-j2/-j$(nproc)/;/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf

manualinstall $aurhelper || error "Fehler beim Installieren des AUR-Helfers."

# Stellen Sie sicher, dass .*-git AUR-Pakete automatisch aktualisiert werden.
$aurhelper -Y --save --devel

# Der Befehl, der alles installiert. Liest die progs.csv-Datei und installiert jedes benötigte Programm auf die erforderliche Weise. Stellen Sie sicher, dass dies nur ausgeführt wird, nachdem der Benutzer erstellt wurde und die Berechtigung hat, sudo ohne Passwort auszuführen und alle Build-Abhängigkeiten installiert sind.
installationloop

# Installieren Sie die dotfiles im Home-Verzeichnis des Benutzers, aber entfernen Sie das .git-Verzeichnis und andere unnötige Dateien.
putgitrepo "$dotfilesrepo" "/home/$name" "$repobranch"
[ -z "/home/$name/.config/newsboat/urls" ] &&
	echo "$rssurls" > "/home/$name/.config/newsboat/urls"
rm -rf "/home/$name/.git/" "/home/$name/README.md" "/home/$name/LICENSE" "/home/$name/FUNDING.yml"

# Installieren Sie vim-Plugins, falls nicht bereits vorhanden.
[ ! -f "/home/$name/.config/nvim/autoload/plug.vim" ] && vimplugininstall

# Wichtigster Befehl! Den Piepton loswerden!
rmmod pcspkr
echo "blacklist pcspkr" >/etc/modprobe.d/nobeep.conf

# Machen Sie zsh zur Standardshell für den Benutzer.
chsh -s /bin/zsh "$name" >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"
sudo -u "$name" mkdir -p "/home/$name/.config/abook/"
sudo -u "$name" mkdir -p "/home/$name/.config/mpd/playlists/"

# Die dbus UUID muss für Artix runit generiert werden.
dbus-uuidgen >/var/lib/dbus/machine-id

# Verwenden Sie Systembenachrichtigungen für Brave auf Artix
echo "export \$(dbus-launch)" >/etc/profile.d/dbus.sh

# Tippen zum Klicken aktivieren
[ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && printf 'Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
	# Linke Maustaste durch Tippen aktivieren
	Option "Tapping" "on"
EndSection' >/etc/X11/xorg.conf.d/40-libinput.conf

# All das unten, um Librewolf mit Add-ons und nicht schlechten Einstellungen zu installieren.

whiptail --infobox "Einstellungen für die Browser-Privatsphäre und Add-ons werden gesetzt..." 7 60

browserdir="/home/$name/.librewolf"
profilesini="$browserdir/profiles.ini"

# Starten Sie Librewolf im Headless-Modus, damit es ein Profil erstellt. Dann dieses Profil in einer Variable speichern.
sudo -u "$name" librewolf --headless >/dev/null 2>&1 &
sleep 1
profile="$(sed -n "/Default=.*.default-default/ s/.*=//p" "$profilesini")"
pdir="$browserdir/$profile"

[ -d "$pdir" ] && makeuserjs

[ -d "$pdir" ] && installffaddons

# Beenden Sie die nun unnötige Librewolf-Instanz.
pkill -u "$name" librewolf

# Erlauben Sie wheel-Benutzern, mit Passwort sudo auszuführen und erlauben Sie mehrere Systembefehle (wie `shutdown`), ohne Passwort auszuführen.
echo "%wheel ALL=(ALL:ALL) ALL" >/etc/sudoers.d/00-larbs-wheel-can-sudo
echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/pacman -Syyuw --noconfirm,/usr/bin/pacman -S -y --config /etc/pacman.conf --,/usr/bin/pacman -S -y -u --config /etc/pacman.conf --" >/etc/sudoers.d/01-larbs-cmds-without-password
echo "Defaults editor=/usr/bin/nvim" >/etc/sudoers.d/02-larbs-visudo-editor
mkdir -p /etc/sysctl.d
echo "kernel.dmesg_restrict = 0" > /etc/sysctl.d/dmesg.conf

# Aufräumen
rm -f /etc/sudoers.d/larbs-temp

# Letzte Nachricht! Installation abgeschlossen!
finalize
