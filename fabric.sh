#!/bin/bash
rootdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
bdir=$rootdir/build
adir=$rootdir/artifacts

function docker_env {
    o=$1
    dop=build/crypto-config/ordererOrganizations/smartm2m.co.kr/tlsca
    dpp=build/crypto-config/peerOrganizations/$o.smartm2m.co.kr/peers/peer0.$o.smartm2m.co.kr
    dap=build/crypto-config/peerOrganizations/$o.smartm2m.co.kr/users/Admin@$o.smartm2m.co.kr
    header="docker exec -it \
        -e CORE_PEER_LOCALMSPID=${o}MSP \
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
    docker run -i -t --rm -v $(pwd):/usr/app --workdir /usr/app \
        hyperledger/fabric-tools:1.4.8 \
        cryptogen generate --config=artifacts/crypto-config.yaml
    mv $rootdir/crypto-config $bdir/crypto-config
}

function configtxgen {
    cp $adir/configtx.yaml $bdir/configtx.yaml
    docker run -i -t --rm -v $bdir:/usr/app --workdir /usr/app \
        -e FABRIC_CFG_PATH=/usr/app \
        hyperledger/fabric-tools:1.4.8 \
        configtxgen -outputBlock mc.block -profile MainChannel -channelID mc

    docker run -i -t --rm -v $bdir:/usr/app --workdir /usr/app \
        -e FABRIC_CFG_PATH=/usr/app \
        hyperledger/fabric-tools:1.4.8 \
        configtxgen -outputCreateChannelTx tca.tx -profile TestChannelA -channelID tca

    docker run -i -t --rm -v $bdir:/usr/app --workdir /usr/app \
        -e FABRIC_CFG_PATH=/usr/app \
        hyperledger/fabric-tools:1.4.8 \
        configtxgen -outputCreateChannelTx tcb.tx -profile TestChannelB -channelID tcb

    docker run -i -t --rm -v $bdir:/usr/app --workdir /usr/app \
        -e FABRIC_CFG_PATH=/usr/app \
        hyperledger/fabric-tools:1.4.8 \
        configtxgen -outputCreateChannelTx tcc.tx -profile TestChannelC -channelID tcc

    rm $bdir/configtx.yaml
    mv $bdir/mc.block $bdir/block/mc.block > /dev/null 2>&1
    mv $bdir/*.tx $bdir/tx/ > /dev/null 2>&1
}

function envgen {
    orgs=(pusan ulsan seoul)
    touch $rootdir/.env
    for org in ${orgs[@]}
    do
        private_key=$(cd $bdir/crypto-config/peerOrganizations/${org}.smartm2m.co.kr/ca && ls *_sk)
        echo "ca_${org}_private_key=$private_key" >> .env
    done
}

function generate {
    cryptogen
    configtxgen
    envgen
}

function build {
    mkdir -p $bdir/block
    mkdir -p $bdir/tx

    generate
}

function clean {
    down
    docker network rm blockchain > /dev/null 2>&1
    rm .env
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
    org=$1
    docker_env $org
    channel=$2

    $header peer0.$org.smartm2m.co.kr peer channel create -c $channel -f build/tx/$channel.tx -o orderer0.smartm2m.co.kr:7050 $tail
    mv $channel.block $bdir/block/
}

function channel_join {
    org=$1
    docker_env $org
    channel=$2

    $header peer0.$org.smartm2m.co.kr peer channel join -b build/block/$channel.block
}

function chaincode_install {
    org=$1
    docker_env $org

    $header cli.smartm2m.co.kr peer chaincode install -n mycc -v 1.0 -p github.com/myeongkil/simple-fabric-network/chaincode/sacc
}

function chaincode_instantiate {
    org=$1
    docker_env $org
    channel=$2
    cc_init_input='{"Args":["kmk","500"]}'
    $header cli.smartm2m.co.kr peer chaincode instantiate -n mycc -v 1.0 -C $channel -c $cc_init_input -o orderer0.smartm2m.co.kr:7050 $tail
}

function chaincode_invoke {
    org=$1
    docker_env $org
    channel=$2
    cc_input='{"Args":["set","zz","500"]}'
    $header cli.smartm2m.co.kr peer chaincode invoke -n mycc -C $channel -c $cc_input -o orderer0.smartm2m.co.kr:7050 $tail
}

function chaincode_query {
    org=$1
    docker_env $org
    channel=$2
    cc_input='{"Args":["get","zz"]}'
    $header cli.smartm2m.co.kr peer chaincode query -n mycc -C $channel -c $cc_input
}

function channel {
    cmd=$1
    shift
    channel_$cmd $@
}

function chaincode {
    cmd=$1
    shift
    chaincode_$cmd $@
}

function all {
    # Clean all
    clean

    # Build Artifacts (crypto-config, genesis.block, channel.tx)
    build

    # Network up (orderer, ca, peer, statedb, cli)
    up

    # Channel create (tca, tcb, tcc)
    channel create pusan tca
    channel create pusan tcb
    channel create ulsan tcc

    # Channel join (pusan, ulsan, seoul)
    channel join pusan tca
    channel join pusan tcb

    channel join ulsan tca
    channel join ulsan tcc

    channel join seoul tcb
    channel join seoul tcc

    # Chaincode install (sacc-mycc:1.0 -> peer0.pusan, peer0.ulsan, peer0.seoul)
    chaincode install pusan
    chaincode install ulsan
    chaincode install seoul

    # Chaincode instantiate (mycc:1.0 -> tca, tcb, tcc)
    chaincode instantiate pusan tca
    chaincode instantiate pusan tcb
    chaincode instantiate ulsan tcc
}

function main {
    if [[ -n $1 ]]
    then
        cmd=$1
        shift
        $cmd $@
    else
        echo "is not supported Commands"
    fi
}

main $@