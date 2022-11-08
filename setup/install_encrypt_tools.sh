git clone https://github.com/containers/skopeo $GOPATH/src/github.com/containers/skopeo
cd $GOPATH/src/github.com/containers/skopeo && make bin/skopeo
apt-get install go-md2man
make install

git clone https://github.com/containers/attestation-agent $GOPATH/src/github.com/attestation-agent
cd $GOPATH/src/github.com/attestation-agent
make KBC=eaa_kbc && make install

git clone -b 2022-poc https://github.com/jialez0/verdictd $GOPATH/src/github.com/verdictd
cd $GOPATH/src/github.com/verdictd
make
make install


