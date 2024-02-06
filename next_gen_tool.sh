#!/bin/bash
if [[ $(id -u) -ne 0 ]] ; then echo "Please run as root" ; exit 1 ; fi
echo //==============================================================
echo   Nessus Vulnerability Scanner 
echo   Special thanks to John Doe for showing this workings. # Deepweb 7jldmpv3ce28lrfn29h6uq56ko7msa1pbc4w9zyq82vrxdei5qoatn2g.onion
echo   Coding by XxRagulxX # Support for debian environment only  
echo //==============================================================

chattr -i -R /opt/nessus

echo "making sure we have prerequisites.."
apt update &>/dev/null

apt -y install curl dpkg expect &>/dev/null

echo " stopping old nessusd in case there is one!"
/bin/systemctl stop nessusd.service &>/dev/null

echo " Downloading Nessus.."
curl -A Mozilla --request GET \
  --url 'https://www.tenable.com/downloads/api/v2/pages/nessus/files/Nessus-latest-debian10_amd64.deb' \
  --output 'Nessus-latest-debian10_amd64.deb' &>/dev/null
{ 
  if [ ! -f Nessus-latest-debian10_amd64.deb ]; then
  echo " Nessus download failed :/"
  exit 0
  fi 
}

echo " Installing Nessus.."
dpkg -i Nessus-latest-debian10_amd64.deb &>/dev/null

echo " Starting service once FIRST TIME INITIALIZATION (we have to do this)"
/bin/systemctl start nessusd.service &>/dev/null

echo " Nessus initializing - it will take like 20 seconds..."
sleep 20

echo " Stopping the nessus service.."
/bin/systemctl stop nessusd.service &>/dev/null

echo " Changing nessus settings"
echo "  Listen port: 11127" # Custom Port 
/opt/nessus/sbin/nessuscli fix --set xmlrpc_listen_port=11127 &>/dev/null

echo "   Theme:       dark"
/opt/nessus/sbin/nessuscli fix --set ui_theme=dark &>/dev/null

echo "   Safe checks: off"
/opt/nessus/sbin/nessuscli fix --set safe_checks=false &>/dev/null

echo "   Logs:        performance" # Debug 
/opt/nessus/sbin/nessuscli fix --set backend_log_level=performance &>/dev/null

echo "   updates:     off" # Currently turned off due to some bug's
/opt/nessus/sbin/nessuscli fix --set auto_update=false &>/dev/null
/opt/nessus/sbin/nessuscli fix --set auto_update_ui=false &>/dev/null
/opt/nessus/sbin/nessuscli fix --set disable_core_updates=true &>/dev/null

echo "   telemetry:   off" # No Ads from Nessus 
/opt/nessus/sbin/nessuscli fix --set report_crashes=false &>/dev/null
/opt/nessus/sbin/nessuscli fix --set send_telemetry=false &>/dev/null

echo " Adding a user you can change this later (u:admin,p:king)"
cat > expect.tmp<<'EOF'
spawn /opt/nessus/sbin/nessuscli adduser admin
expect "Login password:"
send "king\r"
expect "Login password (again):"
send "king\r"
expect "*(can upload plugins, etc.)? (y/n)*"
send "y\r"
expect "*(the user can have an empty rules set)"
send "\r"
expect "Is that ok*"
send "y\r"
expect eof
EOF
expect -f expect.tmp &>/dev/null
rm -rf expect.tmp &>/dev/null

echo " Downloading New plugins..."
curl -A Mozilla -o all-2.0.tar.gz \
  --url 'https://plugins.nessus.org/v2/nessus.php?f=all-2.0.tar.gz&u=4e2abfd83a40e2012ebf6537ade2f207&p=29a34e24fc12d3f5fdfbb1ae948972c6' &>/dev/null
{ 
  if [ ! -f all-2.0.tar.gz ]; then
  echo " o plugins all-2.0.tar.gz download failed :/ exiting. get copy of it from t.me/pwn3rzs"
  exit 0
  fi 
}

echo " Installing plugins.."
/opt/nessus/sbin/nessuscli update all-2.0.tar.gz &>/dev/null

echo " Fetching version number.."
vernum=$(curl https://plugins.nessus.org/v2/plugins.php 2> /dev/null)

echo " Building plugin feed..."
cat > /opt/nessus/var/nessus/plugin_feed_info.inc <<EOF
PLUGIN_SET = "${vernum}";
PLUGIN_FEED = "ProfessionalFeed (Direct)";
PLUGIN_FEED_TRANSPORT = "Tenable Network Security Lightning";
EOF

echo " Protecting files.."
chattr -i /opt/nessus/lib/nessus/plugins/plugin_feed_info.inc &>/dev/null
cp /opt/nessus/var/nessus/plugin_feed_info.inc /opt/nessus/lib/nessus/plugins/plugin_feed_info.inc &>/dev/null

echo " Let's set everything immutable..."
chattr +i /opt/nessus/var/nessus/plugin_feed_info.inc &>/dev/null
chattr +i -R /opt/nessus/lib/nessus/plugins &>/dev/null

chattr -i /opt/nessus/lib/nessus/plugins/plugin_feed_info.inc &>/dev/null
chattr -i /opt/nessus/lib/nessus/plugins  &>/dev/null

echo " Starting service.."
/bin/systemctl start nessusd.service &>/dev/null
echo " Wait for 20 sec for server to setup up"
sleep 20
echo " Patching and Monitoring Nessus progress. Following line updates every 10 seconds until 100%"
zen=0
while [ $zen -ne 100 ]
do
 statline=`curl -sL -k https://localhost:11127/server/status|awk -F"," -v k="engine_status" '{ gsub(/{|}/,""); for(i=1;i<=NF;i++) { if ( $i ~ k ){printf $i} } }'`
 if [[ $statline != *"engine_status"* ]]; then echo -ne "\n Problem: Nessus server unreachable? Trying again..\n"; fi
 echo -ne "\r $statline"
 if [[ $statline == *"100"* ]]; then zen=100; else sleep 10; fi
done

echo -ne '\n  Done!\n'
echo
echo "        Access your Nessus:  https://localhost:11127/"
echo "                             U: admin"
echo "                             P: king"
echo ""
read -p "Press enter to continue"
