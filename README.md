# blockchain master
lecturer : myeongkil

>> 2020.11.13 - first commit, This is the content that was conducted during the blockchain-master-training-lecture

>> 2020.11.15 - after lecture, v1.0 update

## Hyperledger Fabric
* v1.4.8 / v0.4.20
* 3 Orgs(each 1 Peer, 1 CA)
* 1 Main Channel (MainChannel)
* 3 Sub Channels (TestChannelA, TestChannlB, TestChannlC)
* 1 Chaincode ([fabric-samples/chaincode/sacc](https://github.com/hyperledger/fabric-samples/tree/release-1.4/chaincode/sacc))

```shell
./fabric.sh all
```
## commands
* clean
* generate
* network up
* channel create
* channel join
* chaincode install
* chaincode instantiate
* chaincode invoke
* chaincode query

```shell
cat fabric.sh | grep function
```
