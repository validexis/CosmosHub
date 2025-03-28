#!/bin/bash
cd $HOME
rm -rf gaia
git clone https://github.com/cosmos/gaia.git
cd gaia
git checkout v23.0.0
make install

​sudo systemctl restart gaiad && sudo journalctl -u gaiad -f --no-hostname -o cat
