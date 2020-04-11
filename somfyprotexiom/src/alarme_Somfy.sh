#!/bin/bash
#----------------------------------------------------------------------------------------------------------------------
# Script alarme_Somfy.sh
# Date : 11/2016
# Version : 2.0
# Par : jcjames_13009 <jcjames_13009 at yahoo.fr>
# Description : Script de pilotage de l'alarme Somfy Protexiom 5000 via Domoticz sur Raspberry Pi
# - Adapatation du script de Seb13 du forum easydomoticz.com pour Alarme Somfy Protexion 600 au modèle Protexion 5000
#   * Lecture des états du système et mise à jour dans Domoticz
#   * Mise en marche de l'alarme Zone A
#   * Mise en marche de l'alarme Zone B
#   * Mise en marche de l'alarme Zone C
#   * Mise en marche de l'alarme Zones A B C
#   * Arrêt de l'alarme Zones A B C
#   * Reset defauts piles, liaisons et alarmes
#	* Gestion liste des éléments et mise à jour dans Domoticz
#----------------------------------------------------------------------------------------------------------------------
# Appel du script
# - Mise à jour des états de l'alarme toutes les 15min via le crontab :
#   */15 * * * * sudo /home/pi/domoticz/scripts/shell/alarme_somfy.sh --Status
# - Pilotage de l'alarme à partir de DOMOTICZ :
#   Ex pour la mise en marche Zone A ajouter dans l'onglet "Action On" du capteur virtuel: 
#   script:///home/pi/domoticz/scripts/shell/alarme_somfy.sh --ZoneAOn 
#----------------------------------------------------------------------------------------------------------------------
# Version : 2.1
# Date : 25/11/2016
# - Ajout d'un "sleep 1" pour éviter les pertes de retour d'état de l'alarme entre chaque cde dans la lecture de l'état 
#	du système et de la liste des éléments
#----------------------------------------------------------------------------------------------------------------------
# Version : 2.2
# Date : 27/11/2016
# - Ajout cde reset defauts piles, liaisons et alarmes
#----------------------------------------------------------------------------------------------------------------------
# Version : 2.3
# Date : 10/12/2016
# - Gestion liste des éléments et mise à jour dans Domoticz
#----------------------------------------------------------------------------------------------------------------------
# Version : 2.4
# Date : 04/01/2017
# - Envoie d'une seule commande pour éviter les pertes de retour d'état de l'alarme entre chaque cde dans la lecture de
#	l'état du système et de la liste des éléments
#----------------------------------------------------------------------------------------------------------------------
# Version 2.5
# Date : 21/12/2017
# - Adaptation du script à Domoticz sur NAS Synology
#   Remplacement de iconv qui n'existe pas sur Synology par uconv
#-----------------------------------------------------------------------------------------------------------------------
# Version 2.6
# Date : 11/05/2019
# Par : Raph2525 <raphael.dematos at gmail.com>
# - Adaptation du script pour faire le choix Protexiom 600, 5000 et/ou NAS Synology
#---------------------------------------------------------------------------------------------------------------------

#Debug=True
Debug=True

#----------------------------------------------------------------------------------------------------------------------
# PARAMETRES ALARME
#----------------------------------------------------------------------------------------------------------------------
# Carte d'authentification perso
declare -A CarteAuthentification

CarteAuthentification=( ["A1"]="xxxx" ["B1"]="xxx" ["C1"]="xxxx" ["D1"]="xxxx" ["E1"]="xxxx" ["F1"]="xxxx" ["A2"]="xxxx" ["B2"]="xxxx" ["C2"]="xxxx" ["D2"]="xxxx" ["E2"]="xxxx" ["F2"]="xxxx" ["A3"]="xxxx" ["B3"]="xxxx" ["C3"]="xxxx" ["D3"]="xxxx" ["E3"]="xxxx" ["F3"]="xxxx" ["A4"]="xxxx" ["B4"]="xxxx" ["C4"]="xxxx" ["D4"]="xxxx" ["E4"]="xxxx" ["F4"]="xxxx" ["A5"]="xxxx" ["B5"]="xxxx" ["C5"]="xxxx" ["D5"]="xxxx" ["E5"]="xxxx" ["F5"]="xxxx" )


# Adresse IP alarme Somfy 
SrvSomfyIp="http://xxx.xxx.xxx.xxx/"

# Code Utilisateur1
CodeUtilisateur1=xxxx

# Type Alarme
AlarmeSomfyType=600 #600, 5000 

#NAS Synology
NasSynology=False

    if [ "$AlarmeSomfyType" = "5000" ]; then
        # URLs alarme SOMFY PROTEXION 5000 GSM
        UrlLogin=$SrvSomfyIp"fr/login.htm"				# Connexion à l'alarme
        UrlLogout=$SrvSomfyIp"logout.htm"				# Déconnexion de l'alarme
        UrlEtat=$SrvSomfyIp"status.xml"					# Etat du système
        UrlPilotage=$SrvSomfyIp"fr/u_pilotage.htm"		# Pilotage alarme
        UrlElements=$SrvSomfyIp"fr/u_listelmt.htm"		# Liste des éléments / Reset défauts
    fi
    if [ "$AlarmeSomfyType" = "600" ]; then  
        UrlLogin=$SrvSomfyIp"m_login.htm"
        UrlLogout=$SrvSomfyIp"m_logout.htm"
        UrlEtat=$SrvSomfyIp"mu_etat.htm"
        UrlPilotage=$SrvSomfyIp"mu_pilotage.htm"   
        UrlElements=$SrvSomfyIp"u_listelmt.htm"
    fi

#----------------------------------------------------------------------------------------------------------------------
# PARAMETRES DOMOTICZ
#----------------------------------------------------------------------------------------------------------------------
# Capteurs virtuels Domoticz
AlarmeSomfyPilesIdx=xxx
AlarmeSomfyRadioIdx=xxx
AlarmeSomfyPorteIdx=xxx
AlarmeSomfyAlarmeIdx=xxx
AlarmeSomfyBoitierIdx=xxx

AlarmeSomfyGSMIdx=xxx
AlarmeSomfySignalGSMIdx=xxx
AlarmeSomfyOperateurGSMIdx=xxx

AlarmeSomfyCameraIdx=xxx

AlarmeSomfyZoneAIdx=xxx
AlarmeSomfyZoneBIdx=xxx
AlarmeSomfyZoneCIdx=xxx
AlarmeSomfyZoneABCIDX=xxx

AlarmeSomfyDOEntreeIdx=xxx
AlarmeSomfyDOServiceIdx=xxx

# Adresse IP et port du serveur Domoticz
SrvDomoticzIp="xxx.xxx.xxx.xxx:8080"

#----------------------------------------------------------------------------------------------------------------------
# FONCTIONS
#----------------------------------------------------------------------------------------------------------------------
# Fonction menu d'aide
Aide() {
	echo -e "\tScript Domoticz Alarme Somfy Protexion 600 & 5000"
	echo -e "\t--help or -h  \t\tMenu d'aide"
	echo -e "\t--Status      \t\tLecture de l'état du système"
	echo -e "\t--Elements    \t\tListe des éléments"
	echo -e "\t--ZoneAOn     \t\tMise en marche de l'alarme Zone A"
	echo -e "\t--ZoneBOn     \t\tMise en marche de l'alarme Zone B"
	echo -e "\t--ZoneCOn     \t\tMise en marche de l'alarme Zone C"
	echo -e "\t--ZonesABCOn  \t\tMise en marche de l'alarme Zones A B C"
	echo -e "\t--AlarmeOff   \t\tArrêt de l'alarme Zones A B C"
	echo -e "\t--RSTPiles    \t\tReset defauts piles"
	echo -e "\t--RSTAlarmes  \t\tReset defauts alarmes"
	echo -e "\t--RSTLiaisons \t\tReset defauts liaisons"
}

# Fonction connexion à l'alarme
login_alarme () {
	# Affichage des URLs
	if [ "$Debug" = "True" ]; then
		echo " ********************************* "
		echo " Liste des URLs"
		echo " ********************************* "
		echo " UrlLogin    = "$UrlLogin
		echo " UrlLogout   = "$UrlLogout
		echo " UrlEtat     = "$UrlEtat
		echo " UrlPilotage = "$UrlPilotage
		echo " UrlElements = "$UrlElements
	fi

	# Récupération du code d'acces
	if [ "$Debug" = "True" ]; then
		echo " Récuperation du code d'accès"
		CodeAcces="$(curl $SrvSomfyIp $UrlLogin | grep -Eoi 'authentification <b>.*</b>')"
		CodeAcces="$(echo "${CodeAcces:20:2}")"
		echo " Code d'accès = "$CodeAcces
	else
		CodeAcces="$(curl -s $SrvSomfyIp $UrlLogin | grep -Eoi 'authentification <b>.*</b>')"
		CodeAcces="$(echo "${CodeAcces:20:2}")"
	fi

	# Récupération du code d'authentification à partir du code d'accès
	CodeAuthentification="${CarteAuthentification["$CodeAcces"]}"
	if [ "$Debug" = "True" ]; then
		echo " Récuperation du code d'authentification"
		echo " Code d'authentification = "$CodeAuthentification
	fi

	# Envoi du code utilisateur1 et du code d'authentification dans l'url Login pour connexion
	if [ "$Debug" = "True" ]; then
		echo " Envoi du code utilisateur1 et du code d'authentification"
		if [ "$NasSynology" = "False" ]; then
            if [ "$AlarmeSomfyType" = "5000" ]; then
                curl -L --cookie cjar --cookie-jar cjar --data "password="$CodeUtilisateur1"&key="$CodeAuthentification"&btn_login=Connexion" $UrlLogin | iconv -f iso8859-1 -t utf-8
            fi
            if [ "$AlarmeSomfyType" = "600" ]; then
                curl -L --cookie cjar --cookie-jar cjar --data "password="$CodeUtilisateur1"&key="$CodeAuthentification"&action=Connexion" $UrlLogin
                echo ""
                echo "Protexiom 600 - Connexion au site Somfy Mobile OK"
                echo ""
            fi
        else
            curl -L --cookie cjar --cookie-jar cjar --data "password="$CodeUtilisateur1"&key="$CodeAuthentification"&btn_login=Connexion" $UrlLogin | uconv -f iso8859-1 -t utf-8
        fi
	else
		if [ "$NasSynology" = "False" ]; then
            if [ "$AlarmeSomfyType" = "5000" ]; then
                curl -s -L --cookie cjar --cookie-jar cjar --data "password="$CodeUtilisateur1"&key="$CodeAuthentification"&btn_login=Connexion" $UrlLogin  | iconv -f iso8859-1 -t utf-8 > /dev/null
            fi
            if [ "$AlarmeSomfyType" = "600" ]; then
                curl -s -L --cookie cjar --cookie-jar cjar --data "password="$CodeUtilisateur1"&key="$CodeAuthentification"&action=Connexion" $UrlLogin > /dev/null            
            fi
        else
            curl -s -L --cookie cjar --cookie-jar cjar --data "password="$CodeUtilisateur1"&key="$CodeAuthentification"&btn_login=Connexion" $UrlLogin  | uconv -f iso8859-1 -t utf-8 > /dev/null
        fi
	fi
}

# Fonction déconnexion de l'alarme
logout_alarme () {
	if [ "$Debug" = "True" ]; then
		echo " Déconnexion de l'alarme"
		if [ "$NasSynology" = "False" ]; then
            if [ "$AlarmeSomfyType" = "5000" ]; then
                curl -L --cookie cjar --cookie-jar cjar $UrlLogout | iconv -f iso8859-1 -t utf-8
                echo "je passe ici ducon"
            fi
            if [ "$AlarmeSomfyType" = "600" ]; then
                curl -L --cookie cjar --cookie-jar cjar $UrlLogout
                echo ""
                echo "Deconnexion du site Somfy Mobile OK"
                echo ""
            fi
       else
            curl -L --cookie cjar --cookie-jar cjar $UrlLogout | uconv -f iso8859-1 -t utf-8
        fi
	else
		if [ "$NasSynology" = "False" ]; then
            if [ "$AlarmeSomfyType" = "5000" ]; then
                curl -s -L --cookie cjar --cookie-jar cjar $UrlLogout | iconv -f iso8859-1 -t utf-8 > /dev/null
            fi
            if [ "$AlarmeSomfyType" = "600" ]; then
                curl -s -L --cookie cjar --cookie-jar cjar $UrlMLogout > /dev/null
            fi
        else
            curl -s -L --cookie cjar --cookie-jar cjar $UrlLogout | uconv -f iso8859-1 -t utf-8 > /dev/null             
        fi
	fi
}

# Fonction mise à jour capteurs Domoticz
# Paramètres: $1 Nom du capteur / $2 On ou Off / $3 Idx du capteur
maj_capteur () {
	if [ "$Debug" = "True" ]; then
		echo " Etat "$1
		if [ "$2" = "On" ]; then
			curl "http://$SrvDomoticzIp/json.htm?type=command&param=switchlight&idx=$3&switchcmd=On"
		else
			curl "http://$SrvDomoticzIp/json.htm?type=command&param=switchlight&idx=$3&switchcmd=Off"
		fi
	else
		if [ "$2" = "On" ]; then
			curl -s "http://$SrvDomoticzIp/json.htm?type=command&param=switchlight&idx=$3&switchcmd=On" > /dev/null
		else
			curl -s "http://$SrvDomoticzIp/json.htm?type=command&param=switchlight&idx=$3&switchcmd=Off" > /dev/null
		fi
	fi
}

#----------------------------------------------------------------------------------------------------------------------
# Menu des options de lancement du script
#----------------------------------------------------------------------------------------------------------------------
while [[ $1 == -* ]]; do
	case "$1" in
		--help|-h) Aide; exit 0;;
		--Status) Status="1"; break;;
		--Elements) Elements="1"; break;;
		--ZoneAOn) ZoneAOn="1"; break;;
		--ZoneBOn) ZoneBOn="1"; break;;
		--ZoneCOn) ZoneCOn="1"; break;;
		--ZonesABCOn) ZonesABCOn="1"; break;;
		--AlarmeOff) AlarmeOff="1"; break;;
		--RSTPiles) RSTPiles="1"; break;;
		--RSTAlarmes) RSTAlarmes="1"; break;;
		--RSTLiaisons) RSTLiaisons="1"; break;;
		--*|-*) shift; break;;
	esac
done

#----------------------------------------------------------------------------------------------------------------------
# Lecture de l'état du système
#----------------------------------------------------------------------------------------------------------------------
if [ "$Status" = "1" ]; then
	# Connexion à l'alarme
	login_alarme
	
	# Lecture de l'état du système et récupération dans les variables
	# Envoie URL http://IPAlarme/status.xml
	# Retour:
	#	<zone0>off</zone0>					-> Zone A
	#	<zone1>off</zone1>					-> Zone B
	#	<zone2>off</zone2>					-> Zone C
	#
	#	<defaut0>ok</defaut0>				-> Piles
	#	<defaut1>ok</defaut1>				-> Radio
	#	<defaut2>ok</defaut2>				-> Porte/Fenêtre
	#	<defaut3>ok</defaut3>				-> Alarme
	#	<defaut4>ok</defaut4>				-> Boitier
	#
	#	<gsm>GSM connecté au réseau</gsm> 	-> GSM
	#	<recgsm>4</recgsm>					-> Signal GSM
	#	<opegsm>"Orange</opegsm>			-> Opérateur GSM
	#	<camera>disabled</camera>			-> Caméra

	# Lecture de l'état du système et stockage dans fichier temporaire
	if [ "$Debug" = "True" ]; then
		echo " Lecture de l'état du système"
		if [ "$NasSynology" = "False" ]; then
            curl -L --cookie cjar --cookie-jar cjar $UrlEtat | iconv -f iso8859-1 -t utf-8 > status
            echo "Recuperation de l etat du systeme"
        else
            curl -L --cookie cjar --cookie-jar cjar $UrlEtat | uconv -f iso8859-1 -t utf-8 > status
        fi
	else
		if [ "$NasSynology" = "False" ]; then
            curl -s -L --cookie cjar --cookie-jar cjar $UrlEtat | iconv -f iso8859-1 -t utf-8 > status
        else
            curl -s -L --cookie cjar --cookie-jar cjar $UrlEtat | uconv -f iso8859-1 -t utf-8 > status
        fi
	fi

	# Déconnexion de l'alarme
	logout_alarme
	
    if [ "$AlarmeSomfyType" = "5000" ]; then
        # Récupération dans les variables
        EtatZoneA="$(grep -Eoi '<zone0>.*' status)"
        EtatZoneA="$(echo "${EtatZoneA:7:-9}")"
        EtatZoneB="$(grep -Eoi '<zone1>.*' status)"
        EtatZoneB="$(echo "${EtatZoneB:7:-9}")"
        EtatZoneC="$(grep -Eoi '<zone2>.*' status)"
        EtatZoneC="$(echo "${EtatZoneC:7:-9}")"

        EtatPiles="$(grep -Eoi '<defaut0>.*' status)"
        EtatPiles="$(echo "${EtatPiles:9:-11}")"
        EtatRadio="$(grep -Eoi '<defaut1>.*' status)"
        EtatRadio="$(echo "${EtatRadio:9:-11}")"
        EtatPorte="$(grep -Eoi '<defaut2>.*' status)"
        EtatPorte="$(echo "${EtatPorte:9:-11}")"
        EtatAlarme="$(grep -Eoi '<defaut3>.*' status)"
        EtatAlarme="$(echo "${EtatAlarme:9:-11}")"
        EtatBoitier="$(grep -Eoi '<defaut4>.*' status)"
        EtatBoitier="$(echo "${EtatBoitier:9:-11}")"

        EtatGSM="$(grep -Eoi '<gsm>.*' status)"
        EtatGSM="$(echo "${EtatGSM:5:-7}")"
        SignalGSM="$(grep -Eoi '<recgsm>.*' status)"
        SignalGSM="$(echo "${SignalGSM:8:-10}")"
        OperateurGSM="$(grep -Eoi '<opegsm>.*' status)"
        OperateurGSM="$(echo "${OperateurGSM:9:-10}")"
            
        EtatCamera="$(grep -Eoi '<camera>.*' status)"
        EtatCamera="$(echo "${EtatCamera:8:-10}")"
    fi
    if [ "$AlarmeSomfyType" = "600" ]; then
        # Recuperation des etats dans les variables
        EtatZoneA="$(grep -Eoi 'zonea.*</td>' status)"
        EtatZoneA="$(echo "${EtatZoneA:28:3}" | sed s/\<//g)"     
        EtatZoneB="$(grep -Eoi 'zoneb.*</td>' status)"
        EtatZoneB="$(echo "${EtatZoneB:28:3}" | sed s/\<//g)"
        EtatZoneC="$(grep -Eoi 'zonec.*</td>' status)"
        EtatZoneC="$(echo "${EtatZoneC:28:3}" | sed s/\<//g)"
        
        EtatPorte="$(grep -Eoi 'Porte.*</td>' status)"
        EtatPorte="$(echo "${EtatPorte:0:24}" | sed s/\<//g)"
        EtatPiles="$(grep -Eoi 'Pile.*</td>' status)"
        EtatPiles="$(echo "${EtatPiles:0:8}")"        
        EtatRadio="$(grep -Eoi 'Communication.*</td>' status)"
        EtatRadio="$(echo "${EtatRadio:0:22}")"
        EtatAlarme="$(grep -Eoi 'Pas.*</td>' status)"
        EtatAlarme="$(echo "${EtatAlarme:0:12}")"        
        EtatBoitier="$(grep -Eoi 'Boîtier.*</td>' status)"
        EtatBoitier="$(echo "${EtatBoitier:0:10}")"
              
    fi
	
	if [ "$Debug" = "True" ]; then
		# Affichage des états
		echo " ******************************************* "
		echo "  Etat du système"
		echo " ******************************************* "
		echo " Zone A                   = "$EtatZoneA
		echo " Zone B                   = "$EtatZoneB
		echo " Zone C                   = "$EtatZoneC
		echo ""
		echo " Etat Piles               = "$EtatPiles
		echo " Etat Communication Radio = "$EtatRadio
		echo " Etat Porte/Fenêtre       = "$EtatPorte
		echo " Etat Alarme              = "$EtatAlarme
		echo " Etat Boitier             = "$EtatBoitier
		echo ""
		echo " Etat GSM                 = "$EtatGSM
		echo " Signal GSM               = "$SignalGSM
		echo " Opérateur GSM            = "$OperateurGSM
		echo ""
		echo " Etat caméra              = "$EtatCamera
	fi
	
	# Mise à jour capteurs Domoticz
	if [ "$Debug" = "True" ]; then
		echo " Mise à jour capteurs Domoticz"
	fi

	# Zone A Double bracket pour ne pas etre sensible a la casse
	if [[ "${EtatZoneA^^}" = "OFF" ]]; then
		maj_capteur ZoneA Off $AlarmeSomfyZoneAIdx
	else
		maj_capteur ZoneA On $AlarmeSomfyZoneAIdx
	fi

	# Zone B
	if [[ "${EtatZoneB^^}" = "OFF" ]]; then
		maj_capteur ZoneB Off $AlarmeSomfyZoneBIdx
	else
		maj_capteur ZoneB On $AlarmeSomfyZoneBIdx
	fi

	# Zone C
	if [[ "${EtatZoneC^^}" = "OFF" ]]; then
		maj_capteur ZoneC Off $AlarmeSomfyZoneCIdx
	else
		maj_capteur ZoneC On $AlarmeSomfyZoneCIdx
	fi
	
    if [ "$AlarmeSomfyType" = "600" ]; then
        # Etat Piles
        if [[ "$EtatPiles" = "Piles OK" ]]; then
            maj_capteur Piles On $AlarmeSomfyPilesIdx
        else
            maj_capteur Piles Off $AlarmeSomfyPilesIdx
        fi

        # Communication Radio ATTENTION : bug -> retour toujours OK / seul l'icône change et passe à false
        if [[ "$EtatRadio" = "Communication radio OK" ]]; then
            maj_capteur Radio On $AlarmeSomfyRadioIdx
        else
            maj_capteur Radio Off $AlarmeSomfyRadioIdx
        fi

        # Porte/Fenêtre
        if [[ "$EtatPorte" = "Porte ou fenêtre fermée" ]]; then
            maj_capteur Porte/Fenetre Off $AlarmeSomfyPorteIdx
        else
            maj_capteur Porte/Fenetre On $AlarmeSomfyPorteIdx
        fi

        # Alarme
        if [[ "$EtatAlarme" = "Pas d'alarme" ]]; then
            maj_capteur Alarme Off $AlarmeSomfyAlarmeIdx
        else
            maj_capteur Alarme On $AlarmeSomfyAlarmeIdx
        fi

        # Boitier
        if [[ "$EtatBoitier" = "Boîtier OK" ]]; then
            maj_capteur Boitier Off $AlarmeSomfyBoitierIdx
        else
            maj_capteur Boitier On $AlarmeSomfyBoitierIdx
        fi
    fi

    
    if [ "$AlarmeSomfyType" = "5000" ]; then
        # Etat Piles
        if [ "$EtatPiles" = "ok" ]; then
            maj_capteur Piles On $AlarmeSomfyPilesIdx
        else
            maj_capteur Piles Off $AlarmeSomfyPilesIdx
        fi

        # Communication Radio
        if [ "$EtatRadio" = "ok" ]; then
            maj_capteur Radio On $AlarmeSomfyRadioIdx
        else
            maj_capteur Radio Off $AlarmeSomfyRadioIdx
        fi

        # Porte/Fenêtre
        if [ "$EtatPorte" = "ok" ]; then
            maj_capteur Porte/Fenetre Off $AlarmeSomfyPorteIdx
        else
            maj_capteur Porte/Fenetre On $AlarmeSomfyPorteIdx
        fi

        # Alarme
        if [ "$EtatAlarme" = "ok" ]; then
            maj_capteur Alarme Off $AlarmeSomfyAlarmeIdx
        else
            maj_capteur Alarme On $AlarmeSomfyAlarmeIdx
        fi

        # Boitier
        if [ "$EtatBoitier" = "ok" ]; then
            maj_capteur Boitier Off $AlarmeSomfyBoitierIdx
        else
            maj_capteur Boitier On $AlarmeSomfyBoitierIdx
        fi

        # GSM
        if [ "$EtatGSM" = "GSM connecté au réseau" ]; then
            maj_capteur GSM On $AlarmeSomfyGSMIdx
        else
            maj_capteur GSM Off $AlarmeSomfyGSMIdx
        fi
	
       if [ "$EtatGSM" = "GSM connecté au réseau" ]; then
            maj_capteur GSM On $AlarmeSomfyGSMIdx
        else
            maj_capteur GSM Off $AlarmeSomfyGSMIdx
        fi
        
        # Niveau Signal GSM
        if [ "$Debug" = "True" ]; then
            echo " Niveau Signal GSM"
            curl "http://$SrvDomoticzIp/json.htm?type=command&param=udevice&idx=$AlarmeSomfySignalGSMIdx&nvalue=0&svalue=$SignalGSM"
        else
            curl -s "http://$SrvDomoticzIp/json.htm?type=command&param=udevice&idx=$AlarmeSomfySignalGSMIdx&nvalue=0&svalue=$SignalGSM" > /dev/null
        fi
            
        # Opérateur GSM
        if [ "$Debug" = "True" ]; then
            echo " Opérateur GSM"
            curl "http://$SrvDomoticzIp/json.htm?type=command&param=udevice&idx=$AlarmeSomfyOperateurGSMIdx&nvalue=0&svalue=$OperateurGSM"
        else
            curl -s "http://$SrvDomoticzIp/json.htm?type=command&param=udevice&idx=$AlarmeSomfyOperateurGSMIdx&nvalue=0&svalue=$OperateurGSM" > /dev/null
        fi
    fi

	# Caméra
	#if [ "$EtatCamera" = "disabled" ]; then
	#	maj_capteur Camera Off $AlarmeSomfyCameraIdx
	#else
	#	maj_capteur Camera On $AlarmeSomfyCameraIdx
	#fi
	
fi	

#----------------------------------------------------------------------------------------------------------------------
# Mise en marche de l'alarme Zones A B C
#----------------------------------------------------------------------------------------------------------------------
if [ "$ZonesABCOn" = "1" ]; then
	# Connexion à l'alarme
	login_alarme
	# Mise en marche de l'alarme Zones A B C
	if [ "$Debug" = "True" ]; then
		echo "Mise en marche de l'alarme Zones A B C"
        if [ "$AlarmeSomfyType" = "5000" ]; then
            #curl -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&hidden=hidden&btn_zone_on_ABC=Marche A B C" $UrlPilotage | iconv -f iso8859-1 -t utf-8
            curl -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&hidden=hidden&btn_zone_on_ABC=Marche A B C" $UrlPilotage | uconv -f iso8859-1 -t utf-8
        fi
        if [ "$AlarmeSomfyType" = "600" ]; then
            curl -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&zone=Marche%20A%20B%20C" $UrlPilotage | iconv -f iso8859-1 -t utf-8
        fi
	else
        if [ "$AlarmeSomfyType" = "5000" ]; then
            #curl -s -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&hidden=hidden&btn_zone_on_ABC=Marche A B C" $UrlPilotage | iconv -f iso8859-1 -t utf-8 > /dev/null
            curl -s -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&hidden=hidden&btn_zone_on_ABC=Marche A B C" $UrlPilotage | uconv -f iso8859-1 -t utf-8 > /dev/null
        fi
        if [ "$AlarmeSomfyType" = "600" ]; then
            curl -s -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&zone=Marche%20A%20B%20C" $UrlPilotage | iconv -f iso8859-1 -t utf-8 > /dev/null
        fi
	fi


	# Déconnexion de l'alarme
	logout_alarme

	# Mise à jour capteurs Domoticz
	if [ "$Debug" = "True" ]; then
		echo " Mise à jour capteurs Domoticz"
	fi
	maj_capteur ZoneA On $AlarmeSomfyZoneAIdx
	maj_capteur ZoneB On $AlarmeSomfyZoneBIdx
	maj_capteur ZoneC On $AlarmeSomfyZoneCIdx
fi

#----------------------------------------------------------------------------------------------------------------------
# Mise en marche de l'alarme Zone A
#----------------------------------------------------------------------------------------------------------------------
if [ "$ZoneAOn" = "1" ]; then
	# Connexion à l'alarme
	login_alarme

	# Mise en marche de l'alarme Zone A
	if [ "$Debug" = "True" ]; then
		echo "Mise en marche de l'alarme Zone A"
		#curl -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&hidden=hidden&btn_zone_on_A=Marche A" $UrlPilotage | iconv -f iso8859-1 -t utf-8
        if [ "$AlarmeSomfyType" = "5000" ]; then
            curl -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&hidden=hidden&btn_zone_on_A=Marche A" $UrlPilotage | uconv -f iso8859-1 -t utf-8
		fi
		if [ "$AlarmeSomfyType" = "600" ]; then
            curl -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&zone=Marche%20A" $UrlPilotage | iconv -f iso8859-1 -t utf-8
        fi
		
	else
		#curl -s -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&hidden=hidden&btn_zone_on_A=Marche A" $UrlPilotage | iconv -f iso8859-1 -t utf-8 > /dev/null
        if [ "$AlarmeSomfyType" = "5000" ]; then #Modification du 05/05/19
            curl -s -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&hidden=hidden&btn_zone_on_A=Marche A" $UrlPilotage | uconv -f iso8859-1 -t utf-8 > /dev/null
		fi
		if [ "$AlarmeSomfyType" = "600" ]; then
            curl -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&zone=Marche%20A" $UrlPilotage | iconv -f iso8859-1 -t utf-8
        fi
	fi

	# Déconnexion de l'alarme
	logout_alarme

	# Mise à jour capteurs Domoticz
	if [ "$Debug" = "True" ]; then
		echo " Mise à jour capteurs Domoticz"
	fi
	maj_capteur ZoneA On $AlarmeSomfyZoneAIdx
fi

#----------------------------------------------------------------------------------------------------------------------
# Mise en marche de l'alarme Zone B
#----------------------------------------------------------------------------------------------------------------------
if [ "$ZoneBOn" = "1" ]; then
	# Connexion à l'alarme
	login_alarme

	# Mise en marche de l'alarme Zone B
	if [ "$Debug" = "True" ]; then
		echo "Mise en marche de l'alarme Zone B"
		#curl -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&hidden=hidden&btn_zone_on_B=Marche B" $UrlPilotage | iconv -f iso8859-1 -t utf-8
        if [ "$AlarmeSomfyType" = "5000" ]; then
            curl -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&hidden=hidden&btn_zone_on_B=Marche B" $UrlPilotage | uconv -f iso8859-1 -t utf-8
		fi
		if [ "$AlarmeSomfyType" = "600" ]; then
            curl -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&zone=Marche%20B" $UrlPilotage | iconv -f iso8859-1 -t utf-8
        fi
		
	else
		#curl -s -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&hidden=hidden&btn_zone_on_B=Marche B" $UrlPilotage | iconv -f iso8859-1 -t utf-8 > /dev/null
        if [ "$AlarmeSomfyType" = "5000" ]; then #Modification du 05/05/19
            curl -s -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&hidden=hidden&btn_zone_on_B=Marche B" $UrlPilotage | uconv -f iso8859-1 -t utf-8 > /dev/null
		fi
		if [ "$AlarmeSomfyType" = "600" ]; then
            curl -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&zone=Marche%20B" $UrlPilotage | iconv -f iso8859-1 -t utf-8
        fi
	fi

	# Déconnexion de l'alarme
	logout_alarme

	# Mise à jour capteurs Domoticz
	if [ "$Debug" = "True" ]; then
		echo " Mise à jour capteurs Domoticz"
	fi
	maj_capteur ZoneB On $AlarmeSomfyZoneBIdx
fi

#----------------------------------------------------------------------------------------------------------------------
# Mise en marche de l'alarme Zone C
#----------------------------------------------------------------------------------------------------------------------
if [ "$ZoneCOn" = "1" ]; then
	# Connexion à l'alarme
	login_alarme

	# Mise en marche de l'alarme Zone C
	if [ "$Debug" = "True" ]; then
		echo "Mise en marche de l'alarme Zone C"
		#curl -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&hidden=hidden&btn_zone_on_C=Marche C" $UrlPilotage | iconv -f iso8859-1 -t utf-8
        if [ "$AlarmeSomfyType" = "5000" ]; then
            curl -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&hidden=hidden&btn_zone_on_C=Marche C" $UrlPilotage | uconv -f iso8859-1 -t utf-8
		fi
		if [ "$AlarmeSomfyType" = "600" ]; then
            curl -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&zone=Marche%20C" $UrlPilotage | iconv -f iso8859-1 -t utf-8
        fi
		
	else
		#curl -s -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&hidden=hidden&btn_zone_on_C=Marche C" $UrlPilotage | iconv -f iso8859-1 -t utf-8 > /dev/null
        if [ "$AlarmeSomfyType" = "5000" ]; then #Modification du 05/05/19
            curl -s -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&hidden=hidden&btn_zone_on_C=Marche C" $UrlPilotage | uconv -f iso8859-1 -t utf-8 > /dev/null
		fi
		if [ "$AlarmeSomfyType" = "600" ]; then
            curl -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&zone=Marche%20C" $UrlPilotage | iconv -f iso8859-1 -t utf-8
        fi
	fi

	# Déconnexion de l'alarme
	logout_alarme

	# Mise à jour capteurs Domoticz
	if [ "$Debug" = "True" ]; then
		echo " Mise à jour capteurs Domoticz"
	fi
	maj_capteur ZoneC On $AlarmeSomfyZoneCIdx
fi

#----------------------------------------------------------------------------------------------------------------------
# Arrêt de l'alarme Zones A B C
#----------------------------------------------------------------------------------------------------------------------
if [ "$AlarmeOff" = "1" ]; then
	# Connexion à l'alarme
	login_alarme

	# Arrêt de l'alarme Zones A B C
	if [ "$Debug" = "True" ]; then
		echo "Arret de l'alarme Zones A B C"
		#curl -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&btn_zone_off_ABC=Arrêt A B C" $UrlPilotage | iconv -f iso8859-1 -t utf-8
        if [ "$AlarmeSomfyType" = "5000" ]; then
            curl -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&btn_zone_off_ABC=Arrêt A B C" $UrlPilotage | uconv -f iso8859-1 -t utf-8
        fi
        if [ "$AlarmeSomfyType" = "600" ]; then
            curl -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&zone=Arr%EAt%20A%20B%20C" $UrlPilotage | iconv -f iso8859-1 -t utf-8
        fi
        
	else
		#curl -s -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&btn_zone_off_ABC=Arrêt A B C" $UrlPilotage | iconv -f iso8859-1 -t utf-8 > /dev/null
        if [ "$AlarmeSomfyType" = "5000" ]; then
            curl -s -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&btn_zone_off_ABC=Arrêt A B C" $UrlPilotage | uconv -f iso8859-1 -t utf-8 > /dev/null
        fi
        if [ "$AlarmeSomfyType" = "600" ]; then
            curl -s -L --cookie cjar --cookie-jar cjar --data "hidden=hidden&zone=Arr%EAt%20A%20B%20C" $UrlPilotage | iconv -f iso8859-1 -t utf-8 > /dev/null
        fi       
	fi

	# Déconnexion de l'alarme
	logout_alarme
	
	# Mise à jour capteurs Domoticz
	if [ "$Debug" = "True" ]; then
		echo " Mise à jour capteurs Domoticz"
	fi
	maj_capteur ZoneA Off $AlarmeSomfyZoneAIdx
	maj_capteur ZoneB Off $AlarmeSomfyZoneBIdx
	maj_capteur ZoneC Off $AlarmeSomfyZoneCIdx
fi

#----------------------------------------------------------------------------------------------------------------------
# Reset defauts piles
#----------------------------------------------------------------------------------------------------------------------
if [ "$RSTPiles" = "1" ]; then
	# Connexion à l'alarme
	login_alarme

	# Reset defauts piles
	if [ "$Debug" = "True" ]; then
		echo "Reset defauts piles"
		if [ "$AlarmeSomfyType" = "5000" ]; then
            #curl -L --cookie cjar --cookie-jar cjar --data "btn_del_pil=Piles" $UrlElements | iconv -f iso8859-1 -t utf-8
            curl -L --cookie cjar --cookie-jar cjar --data "btn_del_pil=Piles" $UrlElements | uconv -f iso8859-1 -t utf-8
        fi
        if [ "$AlarmeSomfyType" = "600" ]; then
            curl -L --cookie cjar --cookie-jar cjar --data "efface=Piles"  $UrlElements | iconv -f iso8859-1 -t utf-8
        fi
	else
		if [ "$AlarmeSomfyType" = "5000" ]; then
            #curl -s -L --cookie cjar --cookie-jar cjar --data "btn_del_pil=Piles" $UrlElements | iconv -f iso8859-1 -t utf-8 > /dev/null
            curl -s -L --cookie cjar --cookie-jar cjar --data "btn_del_pil=Piles" $UrlElements | uconv -f iso8859-1 -t utf-8 > /dev/null
        fi
        if [ "$AlarmeSomfyType" = "600" ]; then
            curl -s -L --cookie cjar --cookie-jar cjar --data "efface=Piles"  $UrlElements | iconv -f iso8859-1 -t utf-8 > /dev/null
        fi
	fi

	# Déconnexion de l'alarme
	logout_alarme
fi

#----------------------------------------------------------------------------------------------------------------------
# Reset defauts alarmes
#----------------------------------------------------------------------------------------------------------------------
if [ "$RSTAlarmes" = "1" ]; then
	# Connexion à l'alarme
	login_alarme

	# Reset defauts alarmes
	if [ "$Debug" = "True" ]; then
		echo "Reset defauts alarmes"
		if [ "$AlarmeSomfyType" = "5000" ]; then
            #curl -L --cookie cjar --cookie-jar cjar --data "btn_del_pil=Alarmes" $UrlElements | iconv -f iso8859-1 -t utf-8
            curl -L --cookie cjar --cookie-jar cjar --data "btn_del_pil=Alarmes" $UrlElements | uconv -f iso8859-1 -t utf-8
        fi
        if [ "$AlarmeSomfyType" = "600" ]; then
            curl -L --cookie cjar --cookie-jar cjar --data "efface=Alarmes"  $UrlElements | iconv -f iso8859-1 -t utf-8
        fi
	else
		if [ "$AlarmeSomfyType" = "5000" ]; then
            #curl -s -L --cookie cjar --cookie-jar cjar --data "btn_del_pil=Alarmes" $UrlElements | iconv -f iso8859-1 -t utf-8 > /dev/null
            curl -s -L --cookie cjar --cookie-jar cjar --data "btn_del_pil=Alarmes" $UrlElements | uconv -f iso8859-1 -t utf-8 > /dev/null
        fi
        if [ "$AlarmeSomfyType" = "600" ]; then
            curl -s -L --cookie cjar --cookie-jar cjar --data "efface=Alarmes"  $UrlElements | iconv -f iso8859-1 -t utf-8 > /dev/null
        fi
	fi

	# Déconnexion de l'alarme
	logout_alarme
fi

#----------------------------------------------------------------------------------------------------------------------
# Reset defauts liaisons
#----------------------------------------------------------------------------------------------------------------------
if [ "$RSTLiaisons" = "1" ]; then
	# Connexion à l'alarme
	login_alarme

	# Reset defauts liaisons
	if [ "$Debug" = "True" ]; then
		echo "Reset defauts liaisons"
		if [ "$AlarmeSomfyType" = "5000" ]; then
            #curl -L --cookie cjar --cookie-jar cjar --data "btn_del_pil=Liaisons" $UrlElements | iconv -f iso8859-1 -t utf-8
            curl -L --cookie cjar --cookie-jar cjar --data "btn_del_pil=Liaisons" $UrlElements | uconv -f iso8859-1 -t utf-8
        fi
        if [ "$AlarmeSomfyType" = "600" ]; then
            curl -L --cookie cjar --cookie-jar cjar --data "efface=Liaisons"  $UrlElements | iconv -f iso8859-1 -t utf-8
        fi
	else
		if [ "$AlarmeSomfyType" = "5000" ]; then
            #curl -s -L --cookie cjar --cookie-jar cjar --data "btn_del_pil=Liaisons" $UrlElements | iconv -f iso8859-1 -t utf-8 > /dev/null
            curl -s -L --cookie cjar --cookie-jar cjar --data "btn_del_pil=Liaisons" $UrlElements | uconv -f iso8859-1 -t utf-8 > /dev/null
        fi
        if [ "$AlarmeSomfyType" = "600" ]; then
            curl -s -L --cookie cjar --cookie-jar cjar --data "efface=Liaisons"  $UrlElements | iconv -f iso8859-1 -t utf-8 > /dev/null
        fi
	fi

	# Déconnexion de l'alarme
	logout_alarme
fi

#----------------------------------------------------------------------------------------------------------------------
# Gestion de la liste des éléments
#----------------------------------------------------------------------------------------------------------------------
if [ "$Elements" = "1" ]; then
	# Connexion à l'alarme
	login_alarme

	# Lecture de la liste des éléments et stockage dans fichier temporaire
	if [ "$Debug" = "True" ]; then
		echo "Gestion liste des éléments"
        if [ "$AlarmeSomfyType" = "5000" ]; then
            #curl -L --cookie cjar --cookie-jar cjar $UrlElements | iconv -f iso8859-1 -t utf-8 > elements
            curl -L --cookie cjar --cookie-jar cjar $UrlElements | uconv -f iso8859-1 -t utf-8 > elements
        fi
        if [ "$AlarmeSomfyType" = "600" ]; then
            #curl -L --cookie cjar --cookie-jar cjar $UrlElements | iconv -f iso8859-1 -t utf-8 > elements
            curl -L --cookie cjar --cookie-jar cjar $UrlElements | iconv -f iso8859-1 -t utf-8 > elements
        fi        
	else
        if [ "$AlarmeSomfyType" = "5000" ]; then
            #curl -L --cookie cjar --cookie-jar cjar $UrlElements | iconv -f iso8859-1 -t utf-8 > elements
            curl -s -L --cookie cjar --cookie-jar cjar $UrlElements | uconv -f iso8859-1 -t utf-8 > elements
        fi
        if [ "$AlarmeSomfyType" = "600" ]; then
            #curl -L --cookie cjar --cookie-jar cjar $UrlElements | iconv -f iso8859-1 -t utf-8 > elements
            curl -s -L --cookie cjar --cookie-jar cjar $UrlElements | iconv -f iso8859-1 -t utf-8 > elements
        fi
	fi

	# Déconnexion de l'alarme
	logout_alarme
	
	# Récupération dans les variables
	TypeElements="$(grep -Eoi 'var item_label.*' elements)"
	NomElements="$(grep -Eoi 'var elt_name.*' elements)"
	EtatElements="$(grep -Eoi 'var item_pause.*' elements)"
	EtatPiles="$(grep -Eoi 'var elt_pile.*' elements)"
	EtatLiaison="$(grep -Eoi 'var elt_onde.*' elements)"
	EtatPortes="$(grep -Eoi 'var elt_porte.*' elements)"
	EtatBoitiers="$(grep -Eoi 'var elt_as.*' elements)"
	EtatAlarme="$(grep -Eoi 'var elt_maison.*' elements)"

	# Affichage des éléments
	if [ "$Debug" = "True" ]; then
		echo " Type des éléments"
		echo $TypeElements
		echo " Nom des éléments"
		echo $NomElements
		echo " Etat des éléments"
		echo $EtatElements
		echo " Etat des piles"
		echo $EtatPiles
		echo " Etat liaison radio"
		echo $EtatLiaison
		echo " Etat détecteurs ouverture"
		echo $EtatPortes
		echo " Etat ouverture boitiers"
		echo $EtatBoitiers
		echo " Etat alarme"
		echo $EtatAlarme
	fi
		
	# Formatage du type des éléments	
	# Suppression des 21 1er caractères et 2 derniers
	TypeElements="$(echo "${TypeElements:21:-2}")"
	# Suppression des "
	TypeElements="$(echo "$TypeElements" | sed s/\"//g)"
	# Suppression des espaces entre les ,
	TypeElements="$(echo "$TypeElements" | sed s/\,\ /\,/g)"
	# Déclaration , comme séparateur
	IFS=","
	# Stockage dans le tableau
	TabTypeElements=($TypeElements)

	# Formatage des noms des éléments
	# Suppression des 21 1er caractères et 2 derniers
	NomElements="$(echo "${NomElements:21:-2}")"
	# Suppression des "
	NomElements="$(echo "$NomElements" | sed s/\"//g)"
	# Suppression des espaces entre les ,
	NomElements="$(echo "$NomElements" | sed s/\,\ /\,/g)"
	# Déclaration , comme séparateur
	IFS=","
	# Stockage dans le tableau
	TabNomElements=($NomElements)
		
	# Formatage état des éléments
	# Suppression des 21 1er caractères et 2 derniers
	EtatElements="$(echo "${EtatElements:21:-2}")"
	# Suppression des "
	EtatElements="$(echo "$EtatElements" | sed s/\"//g)"
	# Suppression des espaces entre les ,
	EtatElements="$(echo "$EtatElements" | sed s/\,\ /\,/g)"
	# Déclaration , comme séparateur
	IFS=","
	# Stockage dans le tableau
	TabEtatElements=($EtatElements)
	# Modification valeurs tableau
	TailleTab=${#TabEtatElements[@]}
	for (( i=0; i<$TailleTab; i++ ))
	do
		if [ ${TabEtatElements["$i"]} = "running" ]; then TabEtatElements["$i"]="Activé"
		else
			TabEtatElements["$i"]="Désactivé"
		fi
	done

	# Formatage état des piles
	# Suppression des 21 1er caractères et 2 derniers
	EtatPiles="$(echo "${EtatPiles:21:-2}")"
	# Suppression des "
	EtatPiles="$(echo "$EtatPiles" | sed s/\"//g)"
	# Suppression des espaces entre les ,
	EtatPiles="$(echo "$EtatPiles" | sed s/\,\ /\,/g)"
	# Déclaration , comme séparateur
	IFS=","
	# Stockage dans le tableau
	TabEtatPiles=($EtatPiles)
	# Modification des valeurs du tableau
	TailleTab=${#TabEtatPiles[@]}
	for (( i=0; i<$TailleTab; i++ ))
	do
		if [ ${TabEtatPiles["$i"]} = "itemhidden" ]; then TabEtatPiles["$i"]="NA"
		else
			if [ ${TabEtatPiles["$i"]} = "itembattok" ]; then TabEtatPiles["$i"]="OK"
			else
				TabEtatPiles["$i"]="NOK"
			fi
		fi
	done

	# Formatage état liaison radio
	# Suppression des 21 1er caractères et 2 derniers
	EtatLiaison="$(echo "${EtatLiaison:21:-2}")"
	# Suppression des "
	EtatLiaison="$(echo "$EtatLiaison" | sed s/\"//g)"
	# Suppression des espaces entre les ,
	EtatLiaison="$(echo "$EtatLiaison" | sed s/\,\ /\,/g)"
	# Déclaration , comme séparateur
	IFS=","
	# Stockage dans le tableau
	TabEtatLiaison=($EtatLiaison)
	# Modification des valeurs du tableau
	TailleTab=${#TabEtatLiaison[@]}
	for (( i=0; i<$TailleTab; i++ ))
	do
		if [ ${TabEtatLiaison["$i"]} = "itemhidden" ]; then TabEtatLiaison["$i"]="NA"
		else
			if [ ${TabEtatLiaison["$i"]} = "itemcomok" ]; then TabEtatLiaison["$i"]="OK"
			else
				TabEtatLiaison["$i"]="NOK"
			fi
		fi
	done
		
	# Récup état détecteurs ouverture
	# Suppression des 21 1er caractères et 2 derniers
	EtatPortes="$(echo "${EtatPortes:21:-2}")"
	# Suppression des "
	EtatPortes="$(echo "$EtatPortes" | sed s/\"//g)"
	# Suppression des espaces entre les ,
	EtatPortes="$(echo "$EtatPortes" | sed s/\,\ /\,/g)"
	# Déclaration , comme séparateur
	IFS=","
	# Stockage dans le tableau
	TabEtatPortes=($EtatPortes)
	# Modification des valeurs du tableau
	TailleTab=${#TabEtatPortes[@]}
	for (( i=0; i<$TailleTab; i++ ))
	do
		if [ ${TabEtatPortes["$i"]} = "itemhidden" ]; then TabEtatPortes["$i"]="NA"
		else
			if [ ${TabEtatPortes["$i"]} = "itemdoorok" ]; then TabEtatPortes["$i"]="Fermée"
			else
				TabEtatPortes["$i"]="Ouverte"
			fi
		fi
	done
		
	# Récup état ouverture boitiers
	# Suppression des 21 1er caractères et 2 derniers
	EtatBoitiers="$(echo "${EtatBoitiers:21:-2}")"
	# Suppression des "
	EtatBoitiers="$(echo "$EtatBoitiers" | sed s/\"//g)"
	# Suppression des espaces entre les ,
	EtatBoitiers="$(echo "$EtatBoitiers" | sed s/\,\ /\,/g)"
	# Déclaration , comme séparateur
	IFS=","
	# Stockage dans le tableau
	TabEtatBoitiers=($EtatBoitiers)
	# Modification des valeurs du tableau
	TailleTab=${#TabEtatBoitiers[@]}
	for (( i=0; i<$TailleTab; i++ ))
	do
		if [ ${TabEtatBoitiers["$i"]} = "itemhidden" ]; then TabEtatBoitiers["$i"]="NA"
		else
			if [ ${TabEtatBoitiers["$i"]} = "itemboxok" ]; then TabEtatBoitiers["$i"]="Fermé"
			else
				TabEtatBoitiers["$i"]="Ouvert"
			fi
		fi
	done
		
	# Récup état alarme
	# Suppression des 21 1er caractères et 2 derniers
	EtatAlarme="$(echo "${EtatAlarme:21:-2}")"
	# Suppression des "
	EtatAlarme="$(echo "$EtatAlarme" | sed s/\"//g)"
	# Suppression des espaces entre les ,
	EtatAlarme="$(echo "$EtatAlarme" | sed s/\,\ /\,/g)"
	# Déclaration , comme séparateur
	IFS=","
	# Stockage dans le tableau
	TabEtatAlarme=($EtatAlarme)
	# Modification des valeurs du tableau
	TailleTab=${#TabEtatAlarme[@]}
	for (( i=0; i<$TailleTab; i++ ))
	do
		if [ ${TabEtatAlarme["$i"]} = "itemhouseok" ]; then TabEtatAlarme["$i"]="Pas d'alarme"
		else
			TabEtatAlarme["$i"]="Alarme"
		fi
	done
		
	# Affichage de la liste des éléments
	if [ "$Debug" = "True" ]; then
		echo " Liste des éléments"
		TailleTab=${#TabNomElements[@]}
		for (( i=0; i<$TailleTab; i++ ))
		do
			echo " Type : "${TabTypeElements["$i"]} "/ Nom : "${TabNomElements["$i"]} "/ Etat : "${TabEtatElements["$i"]} "/ Etat piles : "${TabEtatPiles["$i"]} "/ Etat liaison : "${TabEtatLiaison["$i"]} "/ Etat portes : "${TabEtatPortes["$i"]} "/ Etat boitiers : "${TabEtatBoitiers["$i"]} "/ Etat alarme : "${TabEtatAlarme["$i"]}
		done	
	fi
	
	# Mise à jour capteurs Domoticz
	if [ "$Debug" = "True" ]; then
		echo " Mise à jour capteurs Domoticz"
	fi

	# DO Entrée
	TailleTab=${#TabNomElements[@]}
	for (( i=0; i<$TailleTab; i++ ))
	do
		if [ ${TabNomElements["$i"]} = "DO Entree" ]; then PosElement=$i
		fi
	done
	if [ ${TabEtatPortes["$PosElement"]} = "Fermée" ]; then
		maj_capteur DOEntree Off $AlarmeSomfyDOEntreeIdx
	else
		maj_capteur DOEntree On $AlarmeSomfyDOEntreeIdx
	fi
	
	# DO Service
	for (( i=0; i<$TailleTab; i++ ))
	do
		if [ ${TabNomElements["$i"]} = "DO Couloir" ]; then PosElement=$i
		fi
	done
	if [ ${TabEtatPortes["$PosElement"]} = "Fermée" ]; then
		maj_capteur DOService Off $AlarmeSomfyDOServiceIdx
	else
		maj_capteur DOService On $AlarmeSomfyDOServiceIdx
	fi
	
fi

exit 0
