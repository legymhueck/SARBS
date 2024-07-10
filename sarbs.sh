#!/bin/sh
# 10.07.2024
# Sergi's Auto Rice Bootstrapping Script (SARBS)
# Original by Luke Smith <luke@lukesmith.xyz>
# angepasst von Sergius
# License: GNU GPLv3

### OPTIONS AND VARIABLES ###

dotfilesrepo="https://github.com/sergi-us/viodrice.git"
progsfile="https://raw.githubusercontent.com/Sergi-us/SARBS/master/progs.csv"
aurhelper="yay"
repobranch="master"
export TERM=ansi
logfile="/home/$name/installation_log.txt"

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


# Alle Ausgaben und Fehler in die Logdatei umleiten
exec > >(tee -a "$logfile") 2>&1


# Funktion zum Schreiben von Lognachrichten
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

### FUNCTIONS ###

installpkg() {
	pacman --noconfirm --needed -S "$1" >/dev/null 2>&1
	error "Stelle sicher, dass du das Skript als root-Benutzer ausführst, auf einer Arch-basierten Distribution bist und eine Internetverbindung hast?"
log "libnewt installiert oder bereits vorhanden."
}

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
		--yesno "Zum jetzigen zeitpunkt muss du YAY manuel instalieren und stelle sicher dass du Arch aktualiert hast -pacman -Syu-.\\n\\nIf beachte das generierte Installationsprotokoll in deinem Home Verzeichniss." 8 70
}

getuserandpass() {
	# Prompts user for new username and password.
	name=$(whiptail --inputbox "Gib deinen neuen Benutzernamen ein." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
	while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
		name=$(whiptail --nocancel --inputbox "Nutzername ungültig. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(whiptail --nocancel --passwordbox "gib ein Passwort für den Benutzer ein." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(whiptail --nocancel --passwordbox "Wiederhole das Passwort." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		pass1=$(whiptail --nocancel --passwordbox "Passwort stimmt nicht überein\\n\\ngib das Passwort für den Nutzer ein." 10 60 3>&1 1>&2 2>&3 3>&1)
		pass2=$(whiptail --nocancel --passwordbox "Wiederhole das Passwort." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
}

usercheck() {
	! { id -u "$name" >/dev/null 2>&1; } ||
		whiptail --title "WARNUNG" --yes-button "FORTFAHREN" \
			--no-button "Nein warte..." \
			--yesno "Der Nutzer \`$name\` exestiert bereits auf diesem System. SARBS kann den Nutzer erstellen, es ÜBERSCHREIBT jedoch alle bestehenden Einstellungen Nutzerdaten.\\n\\nSARBS wird AUCH deine Daten Löschen (oder auch nicht, die Funktion ist noch in der Entwicklung, also verlasse dich nicht drauf. Entweder hast du das Skript angepasst oder du konfigurierst einen neuen Nutzer Drücker <FORTFAHREN> wenn du weißt was du tust.\\n\\nBedenke auch, SARBS wird das Passwort vom $name's ändern, zu dem welchen du gerade vergeben hast." 14 70
}

preinstallmsg() {
	whiptail --title "Let's get this party started!" --yes-button "Let's go!" \
		--no-button "Nee, lass ma!" \
		--yesno "Der Rest der Installation läuft automatisch, gönn dir ein Erfrischungsgetränk und relax.\\n\\nEs wird seine Zeit brauchen, sobald der Installationsprozess abgeschlossen ist, hast du ein fertig Konfiguriertes Süstem.\\n\\nWenn du jetzt <Let's go!> drückst, beginnt die Installation!" 13 60 || {
		clear
		exit 1
	}
}

adduserandpass() {
	# Adds user `$name` with password $pass1.
	whiptail --infobox "Adding user \"$name\"..." 7 50
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
		whiptail --infobox "Refreshing Arch Keyring..." 7 40
		pacman --noconfirm -S archlinux-keyring >/dev/null 2>&1
		;;
	*)
		whiptail --infobox "Enabling Arch Repositories for more a more extensive software collection..." 7 40
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
    # Installs $1 manually. Used only for AUR helper here.
    # Should be run after repodir is created and var is set.
    if pacman -Qq "$1" &>/dev/null; then
        return 0
    fi

    whiptail --infobox "Installing \"$1\" manually." 7 50

    sudo -u "$name" mkdir -p "$repodir/$1"
    if sudo -u "$name" git -C "$repodir" clone --depth 1 --single-branch --no-tags -q "https://aur.archlinux.org/$1.git" "$repodir/$1"; then
        cd "$repodir/$1" || return 1
    else
        cd "$repodir/$1" || return 1
        sudo -u "$name" git pull --force origin master || return 1
    fi

    sudo -u "$name" makepkg --noconfirm -si >/dev/null 2>&1 || return 1
}

#manualinstall() {
#	# Installs $1 manually. Used only for AUR helper here.
#	# Should be run after repodir is created and var is set.
#	pacman -Qq "$1" && return 0
#	whiptail --infobox "Installing \"$1\" manually." 7 50
#	sudo -u "$name" mkdir -p "$repodir/$1"
#	sudo -u "$name" git -C "$repodir" clone --depth 1 --single-branch \
#		--no-tags -q "https://aur.archlinux.org/$1.git" "$repodir/$1" ||
#		{
#			cd "$repodir/$1" || return 1
#			sudo -u "$name" git pull --force origin master
#		}
#	cd "$repodir/$1" || exit 1
#	sudo -u "$name" -D "$repodir/$1" \
#		makepkg --noconfirm -si >/dev/null 2>&1 || return 1
#}

maininstall() {
    # Installs all needed programs from main repo.
    whiptail --title "SARBS Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 9 70
    installpkg "$1"
}

#maininstall() {
#	# Installs all needed programs from main repo.
#	whiptail --title "SARBS Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 9 70
#	installpkg "$1"
#}

gitmakeinstall() {
    progname="${1##*/}"
    progname="${progname%.git}"
    dir="$repodir/$progname"
    whiptail --title "SARBS Installation" \
        --infobox "Installing \`$progname\` ($n of $total) via \`git\` and \`make\`. $(basename "$1") $2" 8 70
    if sudo -u "$name" git -C "$repodir" clone --depth 1 --single-branch --no-tags -q "$1" "$dir"; then
        cd "$dir" || return 1
    else
        cd "$dir" || return 1
        sudo -u "$name" git pull --force origin master || return 1
    fi

    sudo -u "$name" make >/dev/null 2>&1 || return 1
    sudo make install >/dev/null 2>&1 || return 1
    cd /tmp || return 1
}

#gitmakeinstall() {
#	progname="${1##*/}"
#	progname="${progname%.git}"
#	dir="$repodir/$progname"
#	whiptail --title "SARBS Installation" \
#		--infobox "Installing \`$progname\` ($n of $total) via \`git\` and \`make\`. $(basename "$1") $2" 8 70
#	sudo -u "$name" git -C "$repodir" clone --depth 1 --single-branch \
#		--no-tags -q "$1" "$dir" ||
#		{
#			cd "$dir" || return 1
#			sudo -u "$name" git pull --force origin master
#		}
#	cd "$dir" || exit 1
#	make >/dev/null 2>&1
#	make install >/dev/null 2>&1
#	cd /tmp || return 1
#}

aurinstall() {
    whiptail --title "SARBS Installation" \
        --infobox "Installing \`$1\` ($n of $total) from the AUR. $1 $2" 9 70
    echo "$aurinstalled" | grep -q "^$1$" && return 1
    sudo -u "$name" $aurhelper -S --noconfirm "$1" >/dev/null 2>&1 || return 1
}

#aurinstall() {
#	whiptail --title "SARBS Installation" \
#		--infobox "Installing \`$1\` ($n of $total) from the AUR. $1 $2" 9 70
#	echo "$aurinstalled" | grep -q "^$1$" && return 1
#	sudo -u "$name" $aurhelper -S --noconfirm "$1" >/dev/null 2>&1
#}

pipinstall() {
    whiptail --title "SARBS Installation" \
        --infobox "Installing the Python package \`$1\` ($n of $total). $1 $2" 9 70
    [ -x "$(command -v "pip")" ] || installpkg python-pip >/dev/null 2>&1 || return 1
    yes | pip install "$1" >/dev/null 2>&1 || return 1
}

#pipinstall() {
#	whiptail --title "SARBS Installation" \
#		--infobox "Installing the Python package \`$1\` ($n of $total). $1 $2" 9 70
#	[ -x "$(command -v "pip")" ] || installpkg python-pip >/dev/null 2>&1
#	yes | pip install "$1"
#}

installationloop() {
    n=0
    tmpfile=$(mktemp /tmp/progs.csv.XXXXXX)

    if [ -f "$progsfile" ]; then
        cp "$progsfile" "$tmpfile" || { echo "Failed to copy $progsfile"; return 1; }
    else
        curl -Ls "$progsfile" | sed '/^#/d' >"$tmpfile" || { echo "Failed to download $progsfile"; return 1; }
    fi

    total=$(wc -l <"$tmpfile")
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
    done <"$tmpfile"

    rm -f "$tmpfile"
}


#installationloop() {
#	([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) ||
#		curl -Ls "$progsfile" | sed '/^#/d' >/tmp/progs.csv
#	total=$(wc -l </tmp/progs.csv)
#	aurinstalled=$(pacman -Qqm)
#	while IFS=, read -r tag program comment; do
#		n=$((n + 1))
#		echo "$comment" | grep -q "^\".*\"$" &&
#			comment="$(echo "$comment" | sed -E "s/(^\"|\"$)//g")"
#		case "$tag" in
#		"A") aurinstall "$program" "$comment" ;;
#		"G") gitmakeinstall "$program" "$comment" ;;
#		"P") pipinstall "$program" "$comment" ;;
#		*) maininstall "$program" "$comment" ;;
#		esac
#	done </tmp/progs.csv
#}

putgitrepo() {
    # Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts
    whiptail --infobox "Downloading and installing config files..." 7 60
    branch=${3:-master}
    dir=$(mktemp -d)
    [ ! -d "$2" ] && mkdir -p "$2"
    chown "$name:wheel" "$dir" "$2"

    if sudo -u "$name" git -C "$repodir" clone --depth 1 \
        --single-branch --no-tags -q --recursive -b "$branch" \
        --recurse-submodules "$1" "$dir"; then
        sudo -u "$name" cp -rfT "$dir" "$2" || { echo "Failed to copy files"; return 1; }
    else
        echo "Failed to clone repository"
        return 1
    fi

    rm -rf "$dir"
}

#putgitrepo() {
#	# Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts
#	whiptail --infobox "Downloading and installing config files..." 7 60
#	[ -z "$3" ] && branch="master" || branch="$repobranch"
#	dir=$(mktemp -d)
#	[ ! -d "$2" ] && mkdir -p "$2"
#	chown "$name":wheel "$dir" "$2"
#	sudo -u "$name" git -C "$repodir" clone --depth 1 \
#		--single-branch --no-tags -q --recursive -b "$branch" \
#		--recurse-submodules "$1" "$dir"
#	sudo -u "$name" cp -rfT "$dir" "$2"
#}

vimplugininstall() {
    # Installs vim plugins.
    whiptail --infobox "Installing neovim plugins..." 7 60
    mkdir -p "/home/$name/.config/nvim/autoload"
    curl -Ls "https://raw.githubusercontent.com/Sergi-us/vim-plug/master/plug.vim" > "/home/$name/.config/nvim/autoload/plug.vim"
    chown -R "$name:wheel" "/home/$name/.config/nvim"
    sudo -u "$name" nvim -c "PlugInstall|q|q"
}


#vimplugininstall() {
#	# Installs vim plugins.
#	whiptail --infobox "Installing neovim plugins..." 7 60
#	mkdir -p "/home/$name/.config/nvim/autoload"
#	curl -Ls "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim" >  "/home/$name/.config/nvim/autoload/plug.vim"
#	chown -R "$name:wheel" "/home/$name/.config/nvim"
#	sudo -u "$name" nvim -c "PlugInstall|q|q"
#}

makeuserjs() {
    # Get the Arkenfox user.js and prepare it.
    arkenfox="$pdir/arkenfox.js"
    overrides="/home/$name/.config/firefox/larbs.js"
    userjs="$pdir/user.js"

    ln -fs "$overrides" "$pdir/user-overrides.js"

    if [ ! -f "$arkenfox" ]; then
        curl -sL "https://raw.githubusercontent.com/arkenfox/user.js/master/user.js" > "$arkenfox"
    fi

    cat "$arkenfox" "$pdir/user-overrides.js" > "$userjs"
    chown "$name:wheel" "$arkenfox" "$userjs"

    # Install the updating script.
    mkdir -p /usr/local/lib /etc/pacman.d/hooks
    cp "/home/$name/.local/bin/arkenfox-auto-update" /usr/local/lib/
    chown root:root /usr/local/lib/arkenfox-auto-update
    chmod 755 /usr/local/lib/arkenfox-auto-update

    # Trigger the update when needed via a pacman hook.
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

#makeuserjs(){
#	# Get the Arkenfox user.js and prepare it.
#	arkenfox="$pdir/arkenfox.js"
#	overrides="$pdir/user-overrides.js"
#	userjs="$pdir/user.js"
#	ln -fs "/home/$name/.config/firefox/larbs.js" "$overrides"
#	[ ! -f "$arkenfox" ] && curl -sL "https://raw.githubusercontent.com/arkenfox/user.js/master/user.js" > "$arkenfox"
#	cat "$arkenfox" "$overrides" > "$userjs"
#	chown "$name:wheel" "$arkenfox" "$userjs"
#	# Install the updating script.
#	mkdir -p /usr/local/lib /etc/pacman.d/hooks
#	cp "/home/$name/.local/bin/arkenfox-auto-update" /usr/local/lib/
#	chown root:root /usr/local/lib/arkenfox-auto-update
#	chmod 755 /usr/local/lib/arkenfox-auto-update
#	# Trigger the update when needed via a pacman hook.
#	echo "[Trigger]
#Operation = Upgrade
#Type = Package
#Target = firefox
#Target = librewolf
#Target = librewolf-bin
#[Action]
#Description=Update Arkenfox user.js
#When=PostTransaction
#Depends=arkenfox-user.js
#Exec=/usr/local/lib/arkenfox-auto-update" > /etc/pacman.d/hooks/arkenfox.hook
#}

installffaddons() {
    addonlist="ublock-origin decentraleyes istilldontcareaboutcookies vim-vixen keepassxc-browser"
    addontmp="$(mktemp -d)"
    trap "rm -fr $addontmp" HUP INT QUIT TERM PWR EXIT
    IFS=' '
    sudo -u "$name" mkdir -p "$pdir/extensions/"
    for addon in $addonlist; do
        if [ "$addon" = "ublock-origin" ]; then
            addonurl="$(curl -sL https://api.github.com/repos/gorhill/uBlock/releases/latest | grep -E 'browser_download_url.*\.firefox\.xpi' | cut -d '"' -f 4)"
        elif [ "$addon" = "keepassxc-browser" ]; then
            addonurl="https://addons.mozilla.org/firefox/downloads/file/3597426/keepassxc_browser-1.8.7.xpi"
        else
            addonurl="$(curl --silent "https://addons.mozilla.org/en-US/firefox/addon/${addon}/" | grep -o 'https://addons.mozilla.org/firefox/downloads/file/[^"]*')"
        fi

        file="${addonurl##*/}"
        sudo -u "$name" curl -LOs "$addonurl" -o "$addontmp/$file"

        id="$(unzip -p "$addontmp/$file" manifest.json | grep "\"id\"")"
        id="${id%\"*}"
        id="${id##*\"}"

        mv "$addontmp/$file" "$pdir/extensions/$id.xpi"
    done
    chown -R "$name:$name" "$pdir/extensions"

    # Fix a Vim Vixen bug with dark mode not fixed on upstream:
    sudo -u "$name" mkdir -p "$pdir/chrome"
    if [ ! -f "$pdir/chrome/userContent.css" ]; then
        echo ".vimvixen-console-frame { color-scheme: light !important; }
#category-more-from-mozilla { display: none !important }" > "$pdir/chrome/userContent.css"
    fi
}

#installffaddons(){
#	addonlist="ublock-origin decentraleyes istilldontcareaboutcookies vim-vixen"
#	addontmp="$(mktemp -d)"
#	trap "rm -fr $addontmp" HUP INT QUIT TERM PWR EXIT
#	IFS=' '
#	sudo -u "$name" mkdir -p "$pdir/extensions/"
#	for addon in $addonlist; do
#		if [ "$addon" = "ublock-origin" ]; then
#			addonurl="$(curl -sL https://api.github.com/repos/gorhill/uBlock/releases/latest | grep -E 'browser_download_url.*\.firefox\.xpi' | cut -d '"' -f 4)"
#		else
#			addonurl="$(curl --silent "https://addons.mozilla.org/en-US/firefox/addon/${addon}/" | grep -o 'https://addons.mozilla.org/firefox/downloads/file/[^"]*')"
#		fi
#		file="${addonurl##*/}"
#		sudo -u "$name" curl -LOs "$addonurl" > "$addontmp/$file"
#		id="$(unzip -p "$file" manifest.json | grep "\"id\"")"
#		id="${id%\"*}"
#		id="${id##*\"}"
#		mv "$file" "$pdir/extensions/$id.xpi"
#	done
#	chown -R "$name:$name" "$pdir/extensions"
#	# Fix a Vim Vixen bug with dark mode not fixed on upstream:
#	sudo -u "$name" mkdir -p "$pdir/chrome"
#	[ ! -f  "$pdir/chrome/userContent.css" ] && sudo -u "$name" echo ".vimvixen-console-frame { color-scheme: light !important; }
##category-more-from-mozilla { display: none !important }" > "$pdir/chrome/userContent.css"
#}

finalize() {
    # Zeigt eine Nachricht an, dass der Installationsprozess abgeschlossen ist
    whiptail --title "Alles erledigt!" \
        --msgbox "Herzlichen Glückwunsch! Vorausgesetzt, es gab keine versteckten Fehler, wurde das Skript erfolgreich abgeschlossen und alle Programme und Konfigurationsdateien sollten vorhanden sein.\\n\\nUm die neue grafische Umgebung zu starten, melde dich ab und wieder als dein neuer Benutzer an, und führe dann den Befehl \"startx\" aus, um die grafische Umgebung zu starten (sie wird automatisch in tty1 gestartet).\\n\\n.t Sergius" 13 80
}

#finalize() {
#	whiptail --title "All done!" \
#		--msgbox "Congrats! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place.\\n\\nTo run the new graphical environment, log out and log back in as your new user, then run the command \"startx\" to start the graphical environment (it will start automatically in tty1).\\n\\n.t Luke" 13 80
#}

### THE ACTUAL SCRIPT ###

### This is how everything happens in an intuitive format and order.

# Überprüfen, ob der Benutzer root auf einer Arch-basierten Distribution ist. Installiere whiptail.
pacman --noconfirm --needed -Sy libnewt ||
    error "Bist du sicher, dass du das Skript als root-Benutzer ausführst, auf einer Arch-basierten Distribution bist und eine Internetverbindung hast?"

# Begrüße den Benutzer und wähle die Dotfiles aus.
welcomemsg || error "Benutzer hat das Skript beendet."
log "Begrüßungsnachricht angezeigt und Dotfiles ausgewählt."

# Benutzername und Passwort abfragen und verifizieren.
getuserandpass || error "Benutzer hat das Skript beendet."
log "Benutzername und Passwort erfolgreich abgefragt und verifiziert."

# Warnung anzeigen, wenn der Benutzer bereits existiert.
usercheck || error "Benutzer hat das Skript beendet."
log "Benutzerüberprüfung abgeschlossen."

# Letzte Chance für den Benutzer, den Installationsprozess abzubrechen.
preinstallmsg || error "Benutzer hat das Skript beendet."
log "Letzte Warnung vor der Installation angezeigt."

### Automatisierter Bereich..

# Refresh Arch keyrings.
refreshkeys ||
	error "Error automatically refreshing Arch keyring. Consider doing so manually."

for x in curl ca-certificates base-devel git ntp zsh; do
	whiptail --title "SARBS Installation" \
		--infobox "Installing \`$x\` which is required to install and configure other programs." 8 70
	installpkg "$x"
done

whiptail --title "SARBS Installation" \
	--infobox "Synchronizing system time to ensure successful and secure installation of software..." 8 70
ntpd -q -g >/dev/null 2>&1

adduserandpass || error "Error adding username and/or password."

[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # Just in case

# Allow user to run sudo without password. Since AUR programs must be installed
# in a fakeroot environment, this is required for all builds with AUR.
trap 'rm -f /etc/sudoers.d/larbs-temp' HUP INT QUIT TERM PWR EXIT
echo "%wheel ALL=(ALL) NOPASSWD: ALL
Defaults:%wheel,root runcwd=*" >/etc/sudoers.d/larbs-temp

# Make pacman colorful, concurrent downloads and Pacman eye-candy.
grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
sed -Ei "s/^#(ParallelDownloads).*/\1 = 5/;/^#Color$/s/#//" /etc/pacman.conf

# Use all cores for compilation.
sed -i "s/-j2/-j$(nproc)/;/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf

manualinstall $aurhelper || error "Failed to install AUR helper."

# Make sure .*-git AUR packages get updated automatically.
$aurhelper -Y --save --devel

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has priviledges to run sudo without a password
# and all build dependencies are installed.
installationloop

# Install the dotfiles in the user's home directory, but remove .git dir and
# other unnecessary files.
putgitrepo "$dotfilesrepo" "/home/$name" "$repobranch"
[ -z "/home/$name/.config/newsboat/urls" ] &&
	echo "$rssurls" > "/home/$name/.config/newsboat/urls"
rm -rf "/home/$name/.git/" "/home/$name/README.md" "/home/$name/LICENSE" "/home/$name/FUNDING.yml"

# Install vim plugins if not alread present.
[ ! -f "/home/$name/.config/nvim/autoload/plug.vim" ] && vimplugininstall

# Most important command! Get rid of the beep!
rmmod pcspkr
echo "blacklist pcspkr" >/etc/modprobe.d/nobeep.conf

# Make zsh the default shell for the user.
chsh -s /bin/zsh "$name" >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"
sudo -u "$name" mkdir -p "/home/$name/.config/abook/"
sudo -u "$name" mkdir -p "/home/$name/.config/mpd/playlists/"

# dbus UUID must be generated for Artix runit.
dbus-uuidgen >/var/lib/dbus/machine-id

# Use system notifications for Brave on Artix
echo "export \$(dbus-launch)" >/etc/profile.d/dbus.sh

# Enable tap to click
[ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && printf 'Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
	# Enable left mouse button by tapping
	Option "Tapping" "on"
EndSection' >/etc/X11/xorg.conf.d/40-libinput.conf

whiptail --infobox "Setting browser privacy settings and add-ons..." 7 60
log "Browser-Datenschutzeinstellungen und Add-Ons werden gesetzt"

browserdir="/home/$name/.librewolf"
profilesini="$browserdir/profiles.ini"

# Start LibreWolf headless to generate a profile. Then get that profile in a variable.
log "Starte LibreWolf im Headless-Modus, um ein Profil zu erstellen"
sudo -u "$name" librewolf --headless >/dev/null 2>&1 &
sleep 5  # Wait a bit longer to ensure the profile is created
profile="$(sed -n "/Default=.*.default-default/ s/.*=//p" "$profilesini")"
pdir="$browserdir/$profile"
log "Profilverzeichnis: $pdir"

# Check if the profile directory exists and run the functions
if [ -d "$pdir" ]; then
    log "Profilverzeichnis existiert, führe makeuserjs und installffaddons aus"
    makeuserjs
    installffaddons
else
    log "Profilverzeichnis existiert nicht, überspringe makeuserjs und installffaddons"
fi

# Kill the now unnecessary LibreWolf instance.
log "Beende die LibreWolf-Instanz"
pkill -u "$name" librewolf

# Allow wheel users to sudo with password and allow several system commands
# (like `shutdown`) to run without password.
log "Konfiguriere Sudoers-Dateien"
echo "%wheel ALL=(ALL:ALL) ALL" >/etc/sudoers.d/00-larbs-wheel-can-sudo
echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/shutdown, /usr/bin/reboot, /usr/bin/systemctl suspend, /usr/bin/wifi-menu, /usr/bin/mount, /usr/bin/umount, /usr/bin/pacman -Syu, /usr/bin/pacman -Syyu, /usr/bin/pacman -Syyu --noconfirm, /usr/bin/loadkeys, /usr/bin/pacman -Syyuw --noconfirm, /usr/bin/pacman -S -y --config /etc/pacman.conf --, /usr/bin/pacman -S -y -u --config /etc/pacman.conf --" >/etc/sudoers.d/01-larbs-cmds-without-password
echo "Defaults editor=/usr/bin/nvim" >/etc/sudoers.d/02-larbs-visudo-editor

# Allow dmesg for all users
log "Setze dmesg-Berechtigungen für alle Benutzer"
mkdir -p /etc/sysctl.d
echo "kernel.dmesg_restrict = 0" > /etc/sysctl.d/dmesg.conf

# Cleanup
log "Bereinige temporäre Sudoers-Dateien"
rm -f /etc/sudoers.d/larbs-temp

# Last message! Install complete!
log "Installation abgeschlossen"
finalize


## All this below to get Librewolf installed with add-ons and non-bad settings.
#whiptail --infobox "Setting browser privacy settings and add-ons..." 7 60
#
#browserdir="/home/$name/.librewolf"
#profilesini="$browserdir/profiles.ini"
#
## Start librewolf headless so it generates a profile. Then get that profile in a variable.
#sudo -u "$name" librewolf --headless >/dev/null 2>&1 &
#sleep 1
#profile="$(sed -n "/Default=.*.default-default/ s/.*=//p" "$profilesini")"
#pdir="$browserdir/$profile"
#
#[ -d "$pdir" ] && makeuserjs
#
#[ -d "$pdir" ] && installffaddons
#
## Kill the now unnecessary librewolf instance.
#pkill -u "$name" librewolf
#
## Allow wheel users to sudo with password and allow several system commands
## (like `shutdown` to run without password).
#echo "%wheel ALL=(ALL:ALL) ALL" >/etc/sudoers.d/00-larbs-wheel-can-sudo
#echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/pacman -Syyuw --noconfirm,/usr/bin/pacman -S -y --config /etc/pacman.conf --,/usr/bin/pacman -S -y -u --config /etc/pacman.conf --" >/etc/sudoers.d/01-larbs-cmds-without-password
#echo "Defaults editor=/usr/bin/nvim" >/etc/sudoers.d/02-larbs-visudo-editor
#mkdir -p /etc/sysctl.d
#echo "kernel.dmesg_restrict = 0" > /etc/sysctl.d/dmesg.conf
#
## Cleanup
#rm -f /etc/sudoers.d/larbs-temp
#
## Last message! Install complete!
#finalize
