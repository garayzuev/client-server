#!/bin/bash
apt-get update && apt-get install curl vim nano logrotate -y

echo "====== CREATE DIRS ======"
mkdir -p /usr/local/etc/xray
mkdir -p /etc/logrotate.d
mkdir -p /var/log/xray

echo "====== DOWNLOAD AND INSTALL XRAY ======"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

echo "====== GENERATE KEYS ======"
# Генерируем UUID для клиента
UUID=$(xray uuid)
# Генерируем пару ключей для Reality
KEYS=$(xray x25519)
PRIVATE_KEY=$(echo "$KEYS" | grep "PrivateKey" | awk '{print $2}')
PUBLIC_KEY=$(echo "$KEYS" | grep "PublicKey" | awk '{print $3}')
# Генерируем ShortID (8 случайных байт в hex)
SHORT_ID=$(openssl rand -hex 8)

echo "====== GENERATE CONFIGS ======"
cat <<EOF > /usr/local/etc/xray/config.json
{
  "log": { 
    "loglevel": "info",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none",
        "fallbacks": [
          { "dest": "8080" }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
	"tcpSettings": {
          "acceptProxyProtocol": false
        },
        "realitySettings": {
          "show": false,
          "dest": "www.google.com:443",
          "xver": 0,
          "serverNames": [
            "www.google.com"
          ],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": [
            "${SHORT_ID}"
          ]
        }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom" }
  ]
}
EOF

chown nobody:nogroup /var/log/xray
systemctl restart xray

echo "====== INIT LOGS ======"
cat <<EOF > /etc/logrotate.d/xray
/var/log/xray/*.log {
    daily
    size 50M
    missingok
    rotate 14
    compress
    notifempty
    copytruncate
    dateext
    dateformat _%Y_%m_%d
}
EOF
echo "====== GENERATE CLIENT ======"
IP=$(curl -L ipv4.myexternalip.com/raw)
echo "Данные ниже нужно добавить в настройки клиента"
cat <<EOF
{
  "log": {
    "level": "warn"
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "tun0",
      "domain_strategy": "ipv4_only",
      "address": [
        "172.16.250.1/30"
      ],
      "auto_route": false,
      "strict_route": false,
      "sniff": true,
      "sniff_override_destination": false
    }
  ],
  "outbounds": [
    {
      "type": "vless",
      "tag": "vless-main",
      "server": "${IP}",
      "server_port": 443,
      "uuid": "${UUID}",
      "flow": "xtls-rprx-vision",
      "packet_encoding": "xudp",
      "tls": {
        "enabled": true,
        "server_name": "www.google.com",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
        "reality": {
          "enabled": true,
          "public_key": "${PUBLIC_KEY}",
          "short_id": "${SHORT_ID}"
        }
      }
    }
  ],
  "route": {
    "auto_detect_interface": true
  }
}
EOF
