// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Script} from "lib/forge-std/src/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";


contract HelperConfig is Script {
    /* u ovaj helper stavljamo stvari iz struct koje ce nam trebaju za deploy */
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        uint256 deployerKey;
    }

    // pravimo default key za anvil
    uint256 public DEFAULT_ANVIL_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    // pravimo constructor pomocu koji biramo koju mrezu ce koristimo
    NetworkConfig public activeNetworkConfig;

    constructor(){
        if(block.chainid == 11155111){
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    // ovo je za sepolia network
    function getSepoliaEthConfig() public view returns(NetworkConfig memory){
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 8281 , // we will update this with our subId
            callbackGasLimit: 500000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    // ovo je za anvil - nije pure jer saljemo tx
    function getOrCreateAnvilConfig() public returns(NetworkConfig memory){
        // prvo proveravamo da activeNetworkConfig nije adress 0 da bi kreirali mocks
        if(activeNetworkConfig.vrfCoordinator != address(0)){
            return activeNetworkConfig;
        }
        /* importujemo  VRFCoordinatorV2Mock i u njegov constructor gledamo parametri koji nam trebaju i ubacujemo ga u brodcast*/
    uint96 baseFee = 0.25 ether; // 0.25 LINK
    uint96 gasPriceLink = 1e9; // 1 gwei LINK

    vm.startBroadcast();
    VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(baseFee, gasPriceLink);
    vm.stopBroadcast();
    LinkToken link = new LinkToken();

    // stavljamo return i menjamo vrfCoordinator samo
    return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 0, // we will update this with our subId
            callbackGasLimit: 500000,
            link: address(link),
            deployerKey: DEFAULT_ANVIL_KEY
        });
    }
    
}