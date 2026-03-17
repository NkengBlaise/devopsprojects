#!/bin/bash
set -euo pipefail

TOMCAT_VERSION='9.0.115'
TOMURL="https://dlcdn.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
APP_REPO='/tmp/vprofile-project'
APP_PROPS='/vagrant/application.properties'

sudo dnf update -y
sudo dnf install -y java-11-openjdk java-11-openjdk-devel git maven wget rsync unzip firewalld

id tomcat &>/dev/null || sudo useradd --system --shell /sbin/nologin --home-dir /usr/local/tomcat tomcat

cd /tmp
wget -q "$TOMURL" -O tomcat.tar.gz
rm -rf apache-tomcat-* /usr/local/tomcat
mkdir -p /usr/local/tomcat
tar -xzf tomcat.tar.gz
sudo rsync -a "/tmp/apache-tomcat-${TOMCAT_VERSION}/" /usr/local/tomcat/
sudo chown -R tomcat:tomcat /usr/local/tomcat

sudo tee /etc/systemd/system/tomcat.service > /dev/null <<'EOSVC'
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=simple
User=tomcat
Group=tomcat
Environment=JAVA_HOME=/usr/lib/jvm/java-11-openjdk
Environment=CATALINA_HOME=/usr/local/tomcat
Environment=CATALINA_BASE=/usr/local/tomcat
WorkingDirectory=/usr/local/tomcat
ExecStart=/usr/local/tomcat/bin/catalina.sh run
ExecStop=/usr/local/tomcat/bin/shutdown.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOSVC

sudo systemctl daemon-reload
sudo systemctl enable --now tomcat
sudo systemctl enable --now firewalld
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload

if [ ! -d "$APP_REPO" ]; then
  git clone -b main https://github.com/hkhcoder/vprofile-project.git "$APP_REPO"
fi

cd "$APP_REPO"
mvn clean package -DskipTests

sudo systemctl stop tomcat
sudo rm -rf /usr/local/tomcat/webapps/ROOT /usr/local/tomcat/webapps/ROOT.war
sudo cp target/vprofile-v2.war /usr/local/tomcat/webapps/ROOT.war
sudo chown tomcat:tomcat /usr/local/tomcat/webapps/ROOT.war
sudo systemctl start tomcat

# Wait for WAR expansion, then apply environment-specific config
for i in {1..30}; do
  if [ -d /usr/local/tomcat/webapps/ROOT/WEB-INF/classes ]; then
    break
  fi
  sleep 2
done

if [ -f "$APP_PROPS" ]; then
  sudo cp "$APP_PROPS" /usr/local/tomcat/webapps/ROOT/WEB-INF/classes/application.properties
  sudo chown tomcat:tomcat /usr/local/tomcat/webapps/ROOT/WEB-INF/classes/application.properties
  sudo systemctl restart tomcat
fi

sudo systemctl status tomcat --no-pager
