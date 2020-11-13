rootdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
bdir=$rootdir/build

function cryptogen {
    docker run -i -t --rm -v $(pwd):/crypto --workdir /crypto \
        hyperledger/fabric-tools:1.4.8 \
        cryptogen generate --config=crypto-config.yaml

    mv $rootdir/crypto-config $bdir
}

function configtxgen {
    docker run -i -t --rm -v $(pwd):/usr/app --workdir /usr/app \
        -e FABRIC_CFG_PATH=/usr/app \
        hyperledger/fabric-tools:1.4.8 \
        configtxgen -outputBlock mc.block -profile MainChannel -channelID mc

    docker run -i -t --rm -v $(pwd):/usr/app --workdir /usr/app \
        -e FABRIC_CFG_PATH=/usr/app \
        hyperledger/fabric-tools:1.4.8 \
        configtxgen -outputCreateChannelTx tca.tx -profile TestChannelA -channelID tca

    docker run -i -t --rm -v $(pwd):/usr/app --workdir /usr/app \
        -e FABRIC_CFG_PATH=/usr/app \
        hyperledger/fabric-tools:1.4.8 \
        configtxgen -outputCreateChannelTx tcb.tx -profile TestChannelB -channelID tcb

    docker run -i -t --rm -v $(pwd):/usr/app --workdir /usr/app \
        -e FABRIC_CFG_PATH=/usr/app \
        hyperledger/fabric-tools:1.4.8 \
        configtxgen -outputCreateChannelTx tcc.tx -profile TestChannelC -channelID tcc

    mv $rootdir/mc.block $bdir/block/mc.block
    mv $rootdir/*.tx $bdir/tx/
}

function generate {
    cryptogen
    configtxgen
}

function build {
    mkdir -p $bdir/block
    mkdir -p $bdir/tx

    generate
}

function clean {
    rm -rf $bdir
}

function all {
    clean
    build
}

function main {
    if [[ -n $1 ]]
    then
        $1
    else
        echo "is not supported Commands"
    fi
}

main $@
# cryptogen