const { ethers } = require("ethers");
const { DefenderRelayProvider, DefenderRelaySigner } = require('defender-relay-client/lib/ethers');
const strongBlockContractAbi = ["function requestAccess(bool isNaaS) payable public", "function naasRequestingFeeInWei() public view returns(uint256)", "function strongFeeInWei() public view returns(uint256)"];
const strongerContractAbi = ["function allowance(address owner, address spender) public view virtual override returns (uint256)", "function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool)"];
const streamContractAbi = ["function sign(uint32 _poolId, bytes32 _description, bytes32 _data, bytes32 _txHash) external"];

async function handler(params) {
  const { strongBlockContractAddress, strongerContractAddress, streamContractAddress } = params.secrets;
  const provider = new DefenderRelayProvider(params);
  const signer = new DefenderRelaySigner(params, provider, { speed: 'fast' });
  const strongerContract = new ethers.Contract(strongerContractAddress, strongerContractAbi, signer);
  const strongBlockContract = new ethers.Contract(strongBlockContractAddress, strongBlockContractAbi, signer);
  const allowance = await strongerContract.allowance( await signer.getAddress(), strongBlockContractAddress);
  const strongerFee = await strongBlockContract.strongFeeInWei();
  if(allowance < strongerFee){
    console.log("Insufficent STRNGR allowance! Increasing allowance...");
    const tx = await strongerContract.increaseAllowance(strongBlockContractAddress, strongerFee);
    //console.log(tx);
    const receipt = await tx.wait();
    //console.log(tx.logs);
  }

  const txValue = await strongBlockContract.naasRequestingFeeInWei();
  const tx = await strongBlockContract.requestAccess(true, { value: txValue });
  console.log(`Calling requestAccess: ${JSON.stringify(tx)}`);
  const receipt = await tx.wait();
  console.log(`requestAccess tx logs: ${JSON.stringify(receipt.logs)}`);
  let eventAbi = [ "event Paid (address entity, uint256 nodeId, bool isBYON, bool isRenewal, uint256 upToBlockNumber)" ];
  let iface = new ethers.utils.Interface(eventAbi);
  let log = iface.parseLog(receipt.logs[0]); // here you can add your own logic to find the correct log
  const nodeId = log.args[1];
  console.log(`Node id to sign: ${nodeId}`);
  if (!params.request || !params.request.body){
    console.log(`No payload detected. Anonymus pool needs to be signed manually.`);
  }else{
    console.log(`Called by webhook/sentinel. Retrieving poolId from payload: ${JSON.stringify(params.request.body)}`);
    const events = params.request.body.events;
    let result = 0;
    for(const evt of events) {
      if(evt.type == "event"){
        if(evt.signature = "PoolReady(uint32,address)"){
          result = evt.params["poolId"];
          console.log(`Pool Id: ${result}`);
        }
      }
  	}
    //const poolId = ethers.utils.hexZeroPad(ethers.utils.hexlify(result), 32);
    const poolId = params.request.body.events[0].matchReasons[1].params["poolId"];
    console.log(`Pool Id: ${poolId}`);
    const description = ethers.utils.formatBytes32String("Node Id");
    const data = ethers.utils.hexZeroPad(ethers.utils.hexlify(nodeId), 32);
    const streamContract = new ethers.Contract(streamContractAddress, streamContractAbi, signer);
  	await streamContract.sign(poolId, description, data, tx.hash);
  }
  return tx.hash;
}

/*async function sign(_signer, _poolId, _description, _data, _hash) {
  const streamContract = new ethers.Contract(streamContractAddress, streamContractAbi, _signer);
  await streamContract.sign(_poolId, _description, _data, _hash);
}*/

module.exports = {
  handler,
  //sign,
}
