rootdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
bdir=$rootdir/build

function docker_env {
    o=$1
    O=$2
    dop=build/crypto-config/ordererOrganizations/smartm2m.co.kr/tlsca
    dpp=build/crypto-config/peerOrganizations/$o.smartm2m.co.kr/peers/peer0.$o.smartm2m.co.kr
    dap=build/crypto-config/peerOrganizations/$o.smartm2m.co.kr/users/Admin@$o.smartm2m.co.kr
    header="docker exec -it \
        -e CORE_PEER_LOCALMSPID=${O}MSP \
        -e CORE_PEER_MSPCONFIGPATH=$dap/msp \
        -e CORE_PEER_TLS_CERT_FILE=$dpp/tls/server.crt \
        -e CORE_PEER_TLS_KEY_FILE=$dpp/tls/server.key \
        -e CORE_PEER_TLS_ROOTCERT_FILE=$dpp/tls/ca.crt \
        -e CORE_PEER_TLS_CLIENTCERT_FILE=$dap/tls/client.crt \
        -e CORE_PEER_TLS_CLIENTKEY_FILE=$dap/tls/client.key \
        -e CORE_PEER_TLS_CLIENTROOTCA_FILE=$dap/tls/ca.crt \
        -e CORE_PEER_ADDRESS=peer0.$o.smartm2m.co.kr:7051"

    tail="--tls true \
        --cafile $dop/tlsca.smartm2m.co.kr-cert.pem \
        --clientauth true \
        --keyfile $dap/tls/client.key \
        --certfile $dap/tls/client.crt"
}

function cryptogen {
    docker run -i -t --rm -v $(pwd):/crypto --workdir /crypto \
        hyperledger/fabric-tools:1.4.8 \
        cryptogen generate --config=crypto-config.yaml
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
    down
    docker network rm blockchain > /dev/null 2>&1
    rm -rf $bdir
}

function down {
    docker-compose -f $rootdir/docker-compose.yaml down -v
}

function up {
    docker network create blockchain > /dev/null 2>&1
    docker-compose -f $rootdir/docker-compose.yaml up -d
}

function channel_create {
    shift
    org=$1
    docker_env $org $2
    channel=$3

    $header peer0.$org.smartm2m.co.kr peer channel create -c $channel -f build/tx/$channel.tx -o orderer0.smartm2m.co.kr:7050 $tail
    mv $channel.block $bdir/block/
}

function channel_join {
    shift
    org=$1
    docker_env $org $2
    channel=$3

    $header peer0.$org.smartm2m.co.kr peer channel join -b build/block/$channel.block
}

function channel {
    shift
    channel_$1 $@
}

function all {
    clean
    build
    up
}

function main {
    if [[ -n $1 ]]
    then
        $1 $@
    else
        echo "is not supported Commands"
    fi
}

main $@
# cryptogen