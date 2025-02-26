#!/bin/bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git jq lz4 build-essential

sudo rm -rf /usr/local/go
curl -Ls https://go.dev/dl/go1.22.8.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
eval $(echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/golang.sh)
eval $(echo 'export PATH=$PATH:$HOME/go/bin' | tee -a $HOME/.profile)
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> $HOME/.bash_profile
source $HOME/.bash_profile
go version

cd $HOME
rm -rf gaia
git clone https://github.com/cosmos/gaia.git
cd gaia
git checkout v22.2.0
make install

gaiad config set client chain-id cosmoshub-4
gaiad config set client keyring-backend test
gaiad config set client node tcp://localhost:26657

gaiad init NODE --chain-id cosmoshub-4

curl -Ls https://snapshots.kjnodes.com/cosmoshub/genesis.json > $HOME/.gaia/config/genesis.json
curl -Ls https://snapshots.kjnodes.com/cosmoshub/addrbook.json > $HOME/.gaia/config/addrbook.json

SEEDS="00bf1f9d3c65137dc99c40cd03864384ce0ef7c3@cosmoshub-mainnet-seed.itrocket.net:34656"
PEERS="2441723e318545be469d43611d331e3271477ede@cosmoshub-mainnet-peer.itrocket.net:34656,e93fbb087acb7c0f8ca850a796310bb745b510b6@23.227.220.132:26656,b6fedf0d6c87628e72cd5a82058b551445168f9f@23.88.75.75:14956,48c5af84afc9e25f62a7189f0260fd907aac5f68@204.16.247.246:26656,8220e8029929413afff48dccc6a263e9ac0c3e5e@204.16.247.237:26656,bb355f5f5c323150d22608a80fc94d67c2f638bd@169.155.47.134:26656,c98397d6dd1b180ed94a3b17903209172c81ed23@54.39.131.64:26661,63f1915e9d052a04cb11243bb90ff67879dd972c@141.98.219.28:26656,88bd49450f1e9ffef6e272b2002862b2c012c315@95.217.43.189:14956,f52b6ca356060842431aa96392af4e9fdeaec436@67.209.53.70:26656,0add711ee2dcedcfb4c575aa1ace3f4995c8d731@170.64.218.141:26090"
sed -i -e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*seeds *=.*/seeds = \"$SEEDS\"/}" \
       -e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*persistent_peers *=.*/persistent_peers = \"$PEERS\"/}" $HOME/.gaia/config/config.toml
       
sed -i 's|minimum-gas-prices =.*|minimum-gas-prices = "0.0025uatom"|g' $HOME/.gaia/config/app.toml
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.gaia/config/config.toml
sed -i -e "s/^indexer *=.*/indexer = \"null\"/" $HOME/.gaia/config/config.toml

sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.gaia/config/app.toml 
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.gaia/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"19\"/" $HOME/.gaia/config/app.toml

CUSTOM_PORT=167
sed -i -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:${CUSTOM_PORT}58\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://0.0.0.0:${CUSTOM_PORT}57\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:${CUSTOM_PORT}60\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:${CUSTOM_PORT}56\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":${CUSTOM_PORT}66\"%" $HOME/.gaia/config/config.toml
sed -i -e "s%^address = \"tcp://localhost:1317\"%address = \"tcp://0.0.0.0:${CUSTOM_PORT}17\"%; s%^address = \":8080\"%address = \":${CUSTOM_PORT}80\"%; s%^address = \"localhost:9090\"%address = \"0.0.0.0:${CUSTOM_PORT}90\"%; s%^address = \"localhost:9091\"%address = \"0.0.0.0:${CUSTOM_PORT}91\"%; s%^address = \"127.0.0.1:8545\"%address = \"0.0.0.0:${CUSTOM_PORT}45\"%; s%^ws-address = \"127.0.0.1:8546\"%ws-address = \"0.0.0.0:${CUSTOM_PORT}46\"%" $HOME/.gaia/config/app.toml

gaiad config set client node tcp://localhost:${CUSTOM_PORT}57

sudo tee /etc/systemd/system/gaiad.service > /dev/null <<EOF
[Unit]
Description=Cosmos node
After=network-online.target​
[Service]
User=$USER
WorkingDirectory=$HOME/.gaia
ExecStart=$(which gaiad) start --home $HOME/.gaia
Restart=on-failure
RestartSec=5
LimitNOFILE=65535​
[Install]
WantedBy=multi-user.target
EOF

curl -L https://snapshots.kjnodes.com/cosmoshub/snapshot_latest.tar.lz4 | tar -Ilz4 -xf - -C $HOME/.gaia

sudo systemctl daemon-reload
sudo systemctl enable gaiad
sudo systemctl restart gaiad && sudo journalctl -u gaiad -fo cat
