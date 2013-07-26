#!/bin/bash
# This script configures a stock Ubuntu server for running ManaServ.
# Copyright (C) 2013  nickstinger@hotmail.com
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program or from the site that you downloaded it
# from; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307   USA

# ------------------------------------------information
# After having successfully installed ManaServ,
# you may want to download and install the latest ManaSource client.
# http://nightlies.manasource.org/
#
# sudo add-apt-repository ppa:mana-developers/ppa
# sudo apt-get -y install mana-daily

# ------------------------------------------information
# After installation, the following commands may be used
# to monitor your server:
#
# service manaserv-account status
# service manaserv-game status

# ------------------------------------------local execution
# Before running this script, you must edit the environment configuration
# section.
#
# The following commands can be used to edit, and run this script:
#
# vi manaserv-init.sh
# chmod 755 manaserv-init.sh
# ./manaserv-init.sh

# ------------------------------------------environment configuration
# Configuration: All settings are required, with default values supplied.

# ManaServ repository url - The ManaServ project will be cloned and
# compiled from the following git repository Url.
initRepository="git://github.com/mana/manaserv.git"

# Network interface binding - ManaServ will listen on the primary
# IP address of the specified interface.  Additionally, at server startup
# ManaServ will run after this interface has been brought online.
initBindingInterface="eth0"

# Database engine - Either "sqlite" or "mysql" may be entered.
# The specified database will be installed and initialized.
# Recommended: ManaWeb management only supports sqlite.
initDbEngine="sqlite"

# MySql Database Passwords - ** IMPORTANT **
# Choose a sufficiently complex password for root (No quote characters, please).
# The default manaserv password is randomly generated.
initMySqlRootPassword="OzzFc73kcqM/l1DKip8sVNClrihAiJu6ZlwB+v6bUwvXKckwjKzAoYaHnc36KR0i"
initMySqlManaPassword="$(echo `dd if=/dev/urandom bs=48 count=1 | openssl enc -base64 | tr -d '\n'`)"

# Logging - Log detail level and log file directory.  Please refer to the following table:
# LEVEL   CONTENT
#     0   Fatal Errors only.
#     1   All Errors.
#     2   Plus warnings.
#     3   Plus standard information.
#     4   Plus debugging information.
initLogLevel="1"
initLogDir="/var/log"

# Net Password - The password used for intra-server communication.
# The default is a randomly generated password.
initNetPassword="$(echo `dd if=/dev/urandom bs=9 count=1 | openssl enc -base64 | tr -d '\n'`)"

# Public (Advertised) IP Addresses or Domain Names - The following settings
# are for the public (static) IP-addresses/domain-names of the server.  The
# default settings are for the primary IP address of the chosen network interface.
# Any server behind a firewall or router will likely require an adjustment to these settings.
initNetPublicChatHost="$(/sbin/ip -o -4 addr list ${initBindingInterface} | awk '{print $4}' | cut -d/ -f1)"
initNetPublicGameHost="$(/sbin/ip -o -4 addr list ${initBindingInterface} | awk '{print $4}' | cut -d/ -f1)"

# ManaSource Client Update Server - The protocol and Url of the client update servers.
initNetDefaultUpdateHost="http://updates.manasource.org/"
initNetClientDataUrl="http://data.manasource.org/"

# ------------------------------------------end environment configuration

# BUILD THE SERVER!

# ------------------------------------------packages
sudo apt-get -y update
sudo apt-get -y upgrade
sudo apt-get -y install git

# ManaServ
sudo apt-get -y install cmake build-essential libxml2-dev libphysfs-dev zlib1g-dev liblua5.1-0-dev libsigc++-2.0-dev

# Sqlite3
if [ "${initDbEngine}" = "sqlite" ]; then
  sudo apt-get -y install sqlite3 libsqlite3-dev
fi

# MySql
if [ "${initDbEngine}" = "mysql" ]; then
  echo "mysql-server-5.5 mysql-server/root_password password ${initMySqlRootPassword}" | sudo debconf-set-selections
  echo "mysql-server-5.5 mysql-server/root_password_again password ${initMySqlRootPassword}" | sudo debconf-set-selections
  sudo apt-get -y install mysql-server-5.5 libmysql++-dev
  echo "PURGE" | sudo debconf-communicate mysql-server-5.5
fi

# ------------------------------------------daemon user account
sudo useradd -m manaserv
sudo groupadd manaservadm
sudo chgrp manaservadm /home/manaserv
sudo chmod 770 /home/manaserv

sudo usermod -G manaservadm "${USER}"

sudo mkdir "${initLogDir}/manaserv"
sudo chown manaserv "${initLogDir}/manaserv"
sudo chgrp manaservadm "${initLogDir}/manaserv"
sudo chmod 770 "${initLogDir}/manaserv"

# ------------------------------------------compilation
git clone "${initRepository}" /tmp/manaserv
cd /tmp/manaserv

# Sqlite3
if [ "${initDbEngine}" = "sqlite" ]; then
  cmake .
fi

# MySql
if [ "${initDbEngine}" = "mysql" ]; then
  cmake -DWITH_MYSQL=1 .
fi

sudo make install

sudo chown manaserv /usr/local/bin/manaserv-account
sudo chgrp manaserv /usr/local/bin/manaserv-account
sudo chmod 110 /usr/local/bin/manaserv-account

sudo chown manaserv /usr/local/bin/manaserv-game
sudo chgrp manaserv /usr/local/bin/manaserv-game
sudo chmod 110 /usr/local/bin/manaserv-game

sudo cp -r /tmp/manaserv/example /home/manaserv/data
sudo chown -R manaserv /home/manaserv/data
sudo chgrp -R manaservadm /home/manaserv/data
sudo chmod 570 /home/manaserv/data
sudo find /home/manaserv/data -type f -exec chmod 460 {} \;
sudo find /home/manaserv/data -type d -exec chmod 570 {} \;

# ------------------------------------------database
# Sqlite3
if [ "${initDbEngine}" = "sqlite" ]; then
  echo "echo '.quit' | sqlite3 -init /tmp/manaserv/src/sql/sqlite/createTables.sql /home/manaserv/mana.db" | sudo sh
  sudo chown manaserv /home/manaserv/mana.db
  sudo chgrp manaservadm /home/manaserv/mana.db
  sudo chmod 660 /home/manaserv/mana.db
  sudo bash -c "cat > /home/manaserv/database.xml" << EOF
<?xml version="1.0"?>
<!--
	Manaserv database configuration file.
	Documentation: http://doc.manasource.org/manaserv.xml
-->
<configuration>
  <option name="sqlite_database" value="/home/manaserv/mana.db"/>
</configuration>
EOF
fi

# MySql
if [ "${initDbEngine}" = "mysql" ]; then
  mysql --user=root --password="${initMySqlRootPassword}" --execute="source /tmp/manaserv/src/sql/mysql/createDatabase.sql"
  mysql --user=root --password="${initMySqlRootPassword}" --execute="source /tmp/manaserv/src/sql/mysql/createTables.sql" mana
  mysql --user=root --password="${initMySqlRootPassword}" --execute="UPDATE mysql.user SET Password=PASSWORD('${initMySqlManaPassword}') WHERE User='mana';" mana
  mysql --user=root --password="${initMySqlRootPassword}" --execute="FLUSH PRIVILEGES;" mana
  sudo bash -c "cat > /home/manaserv/database.xml" << EOF
<?xml version="1.0"?>
<!--
	Manaserv database configuration file.
	Documentation: http://doc.manasource.org/manaserv.xml
-->
<configuration>
  <option name="mysql_hostname" value="localhost"/>
  <option name="mysql_port" value="3306"/>
  <option name="mysql_database" value="mana"/>
  <option name="mysql_username" value="mana"/>
  <option name="mysql_password" value="${initMySqlManaPassword}"/>
</configuration>
EOF
fi

sudo chown manaserv /home/manaserv/database.xml
sudo chgrp manaservadm /home/manaserv/database.xml
sudo chmod 460 /home/manaserv/database.xml

# ------------------------------------------manaserv configuration
sudo bash -c "cat > /home/manaserv/manaserv.xml" << EOF
<?xml version="1.0"?>
<!--
	An example configuration file.

	Documentation: http://doc.manasource.org/manaserv.xml

	Developers:	If you add any new parameters read from this configuration file
	don't forget to update the wiki documentation!
-->
<configuration>
<!--
    Note that you can split the config into multiple files. For example you can
    create a global config file and let server specific settings into others,
    including the main one.
    Including works like this:
    <include file="otherconfig.xml" />
-->
<include file="database.xml" />
<include file="network.xml" />

<!-- Paths configuration ******************************************************
 Set here the different paths used by both the server to find data.
-->
 <!-- Paths to data files -->
 <option name="worldDataPath" value="/home/manaserv/data" />

<!-- end of paths configuration ******************************************* -->

<!-- Logs configuration *******************************************************
 Set here the different paths used by both the server
 to store statistics and log files.
-->

 <!--
 Log output configuration, relative to the folders where the servers were ran.
 -->
 <option name="log_statisticsFile" value="${initLogDir}/manaserv/manaserv.stats"/>
 <option name="log_accountServerFile" value="${initLogDir}/manaserv/account.log"/>
 <option name="log_gameServerFile" value="${initLogDir}/manaserv/game.log"/>

 <!--
 Log levels configuration.
 Available values are:
   0. Fatal Errors only.
   1. All Errors.
   2. Plus warnings.
   3. Plus standard information.
   4. Plus debugging information.
 -->
 <option name="log_gameServerLogLevel" value="${initLogLevel}"/>
 <option name="log_accountServerLogLevel" value="${initLogLevel}"/>

 <!--
 Enable log rotation when one log file reaches a max size
 and/or the current day has changed.
 -->
 <option name="log_enableRotation" value="true"/>
 <!--
 Set the max log file size. Disabled if set to 0.
 -->
 <option name="log_maxFileSize" value="1024"/>
 <!--
 Change the log file each day.
 -->
 <option name="log_perDay" value="true"/>

 <!--
 Set whether both servers will log also on the standard output.
 -->
 <option name="log_toStandardOutput" value="false"/>

<!-- end of logs configuration ****************************************** -->

<!-- Network options configuration ********************************************
 Set here the different network-related options to set up the servers
 hosts and ports, for instance.
-->

 <!--
 ATTENTION: This is a very important option!
 the net password is used to let the servers (game and account) speak to each
 other in a crypted way.
 This option is REQUIRED FOR THE SERVERS TO START.
 -->
 <option name="net_password" value="${initNetPassword}"/>

 <!--
 The game server uses this address to connect to the account server. Clients
 will also need to be able to connect to the account server through it.
 Don't use the 'localhost' value when running a public server,
 but rather the public name.

 The port options set the port to listen to clients and to game servers
 respectively.
 -->
 <option name="net_accountListenToClientPort" value="9601"/>
 <option name="net_accountListenToGamePort" value="9602"/>

 <!--
 Host the chat server will listen to. Defaulted to 'localhost'.
 Don't use the 'localhost' value when running a public server,
 but rather the public name.
 -->
 <option name="net_chatListenToClientPort" value="9603"/>
 <!-- needed to set when hosting behind router or in situations
      where you cannot bind the server to the public url -->
 <option name="net_publicChatHost" value="${initNetPublicChatHost}"/>

 <!--
 The clients use this address to connect to a game server on this machine.
 Don't use the 'localhost' value when running a public server,
 but rather the public name.
 -->
 <option name="net_gameListenToClientPort" value="9604"/>
 <!-- needed to set when hosting behind router or in situations
      where you cannot bind the server to the public url -->
 <option name="net_publicGameHost" value="${initNetPublicGameHost}"/>

 <!--
 Usually the first game server activates all maps. To prevent this you need to
 set a name for the server and set this name in the maps.xml (see documentation
 there).
 -->
 <!--
 <option name="net_gameServerName" value="myServer" />
 -->

 <!--
 Update host url: E.g.: "http://updates.manasource.org/"
 It gives the http folder where the update files can be downloaded.
 -->
 <option name="net_defaultUpdateHost" value="${initNetDefaultUpdateHost}" />

 <!--
 Client data url: E.g.: "http://data.manasource.org/"
 Example for local use: "file:///home/user/clientdata/"
 The base URL where the client will get its data from. This is a new update
 mechanism that replaces the update host, used by the Mana Mobile client.
 -->
 <option name="net_clientDataUrl" value="${initNetClientDataUrl}" />

 <!-- Max connected clients allowed. -->
 <option name="net_maxClients" value="1000"/>

 <!-- Debug mode for network messages (increases bandwidth usage) -->
 <option name="net_debugMode" value="false"/>

<!-- end of network options configuration ********************************* -->

<!-- Accounts configuration ***************************************************
 Set here the different options related to players accounts
 and used at their creation.
-->

 <option name="account_allowRegister" value="1" />
 <option name="account_denyRegisterReason"
         value="The server administrator has disabled automatic registration!"/>
 <option name="account_minEmailLength" value="7" />
 <option name="account_maxEmailLength" value="128" />
 <option name="account_minNameLength" value="4" />
 <option name="account_maxNameLength" value="15" />
 <option name="account_minPasswordLength" value="6" />
 <option name="account_maxPasswordLength" value="25" />
 <option name="account_maxCharacters" value="3" />
 <option name="account_maxGuildsPerCharacter" value="1" />

<!-- end of accounts configuration **************************************** -->

<!-- Characters configuration *************************************************
 Set here the different options related to players characters.
-->

 <option name="char_numHairStyles" value="17" />
 <option name="char_numHairColors" value="11" />
 <option name="char_numGenders" value="2" />
 <option name="char_minNameLength" value="4" />
 <option name="char_maxNameLength" value="25" />

 <!--
 New player starting location. The map should be defined in data/maps.xml.
 -->
 <option name="char_startMap" value="1"/>
 <!--
     Respawn coordinates on the start map:
     In pixels, not in tiles.
 -->
 <option name="char_startX" value="1024"/>
 <option name="char_startY" value="1024"/>

 <!-- Respawn options -->
 <option name="char_respawnMap" value="1"/>
 <!--
     Respawn coordinates on the respawn map:
     In pixels, not in tiles.
 -->
 <option name="char_respawnX" value="1024"/>
 <option name="char_respawnY" value="1024"/>

 <!-- Default Map id at character loading -->
 <option name="char_defaultMap" value="1" />

<!-- end of characters configuration ************************************** -->

<!-- Game configuration *************************************************
 Set here the different options related to the gameplay.
-->

 <!--
 Set the player's character visual range around him in pixels.
 Monsters and other beings further than this value won't appear in its sight.
 -->
 <option name="game_visualRange" value="448"/>
 <!--
 The time in seconds an item standing on the floor will remain before vanishing.
 Set it to 0 to disable it.
 -->
 <option name="game_floorItemDecayTime" value="0" />

 <!--
 Set how much time the auto-regeneration is stopped when hurt.
 (in 1/10th seconds.)
 -->
 <option name="game_hpRegenBreakAfterHit" value="0" />

 <!--
 Default PVP (Player-versus-player) rule on a map not setting this property.
 Values available: none (No PVP), free (All PVP).
 -->
 <option name="game_defaultPvp" value="" />

<!-- end of game configuration ******************************************** -->

<!-- Commands configuration ***************************************************
 Set here the different options related to chat commands.
-->

 <!--
 Default mute command length (in seconds.)
 -->
 <option name="command_defaultMuteLength" value="60" />

<!-- end of commands configuration **************************************** -->

<!-- Chat configuration ***************************************************
 Set here the different options related to chat handling.
-->

 <option name="chat_maxChannelNameLength" value="15" />

 <!--
 TODO: Dehard-code those values, or redo the chat channeling system
 to not make use of them.
        MAX_PUBLIC_CHANNELS_RANGE  = 1000,
        MAX_PRIVATE_CHANNELS_RANGE = 10000,
        MAX_CHANNEL_ANNOUNCEMENT   = 150,
        MAX_CHANNEL_PASSWORD       = 12,
 -->

<!-- end of chat configuration ******************************************** -->

<!-- Mail configuration ***************************************************
 Set here the different options related to the mail system.
-->

 <option name="mail_maxAttachments" value="3" />
 <option name="mail_maxLetters" value="10" />

<!-- end of mail configuration ******************************************** -->

<!-- Scripting configuration ********************************************** -->

 <option name="script_engine" value="lua"/>
 <option name="script_mainFile" value="scripts/main.lua"/>

<!-- End of scripting configuration *************************************** -->

</configuration>
EOF

sudo chown manaserv /home/manaserv/manaserv.xml
sudo chgrp manaservadm /home/manaserv/manaserv.xml
sudo chmod 460 /home/manaserv/manaserv.xml

# ------------------------------------------upstart configuration
sudo bash -c "cat > /etc/init/manaserv-account.conf" << EOF
# manaserv-account-example

description "manaserv-account service"
author "Nick Stinger <nickstinger@hotmail.com>"

start on (local-filesystems and net-device-up IFACE=${initBindingInterface})
stop on shutdown

respawn                # restart when job dies
respawn limit 5 60     # give up restart after 5 respawns in 60 seconds

script
  BINDING_ADDRESS=\$(/sbin/ip -o -4 addr list ${initBindingInterface} | awk '{print \$4}' | cut -d/ -f1)

  cat << END > /home/manaserv/network.xml
<?xml version="1.0"?>
<configuration>
  <option name="net_accountHost" value="\${BINDING_ADDRESS}"/>
  <option name="net_chatHost" value="\${BINDING_ADDRESS}"/>
  <option name="net_gameHost" value="\${BINDING_ADDRESS}"/>
</configuration>
END

  cd /home/manaserv
  exec sudo -u manaserv /usr/local/bin/manaserv-account --config /home/manaserv/manaserv.xml
end script
EOF

sudo bash -c "cat > /etc/init/manaserv-game.conf" << EOF
# manaserv-game-example

description "manaserv-game service"
author "Nick Stinger <nickstinger@hotmail.com>"

start on (local-filesystems and net-device-up IFACE=${initBindingInterface})
stop on shutdown

respawn                # restart when job dies
respawn limit 5 60     # give up restart after 5 respawns in 60 seconds

script
  BINDING_ADDRESS=\$(/sbin/ip -o -4 addr list ${initBindingInterface} | awk '{print \$4}' | cut -d/ -f1)

  cat << END > /home/manaserv/network.xml
<?xml version="1.0"?>
<configuration>
  <option name="net_accountHost" value="\${BINDING_ADDRESS}"/>
  <option name="net_chatHost" value="\${BINDING_ADDRESS}"/>
  <option name="net_gameHost" value="\${BINDING_ADDRESS}"/>
</configuration>
END

  cd /home/manaserv
  exec sudo -u manaserv /usr/local/bin/manaserv-game --config /home/manaserv/manaserv.xml
end script
EOF

sudo initctl reload-configuration
sudo service manaserv-account start
sudo service manaserv-game start

# ------------------------------------------cleanup
sudo rm -rf /tmp/manaserv
echo "You will need to relog for group permissions to take effect."

# Next version to install manaweb from https://github.com/mana/manaweb.git
