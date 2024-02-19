// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    // createSubscriptionUsingConfig() nam pomaze da dobijemo config koji nam treba
    function createSubscriptionUsingConfig() public returns (uint64) {
        // koristimo helperconfig jer nam treba adresa od vrfCoordinator iz njega
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , , , , uint256 deployerKey) = helperConfig
            .activeNetworkConfig();
        // ovo kreira broj subskripcije za adresu koju smo izvukli iz helpera
        return createSubscription(vrfCoordinator, deployerKey);
    }

    // createSubscription(vrfCoordinator) nam pomaze da kreiramo subscription na osnovu trenutnog coordinatora koji koristimo
    function createSubscription(
        address vrfCoordinator,
        uint256 deployerKey
    ) public returns (uint64) {
        console.log("Creating subscription on ChainId: ", block.chainid);
        vm.startBroadcast(deployerKey);
        // u VRFCoordinatorV2Mock se nalazi funkcija createSubscription i zato njega koristimo
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Your subId is: ", subId);
        console.log("Update subscriptionId in HelperConfig.s.sol");
        return subId;
    }

    // subscription id je uin64
    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

// kreiramo i kontrakt koji ce da fundira subskripciju
contract FundSubscription is Script {
    uint96 public FUND_AMOUNT = 3 ether;

    // da bi fundirali treba nam subid, vrfcoordinator(vrfcoordinatorV2) adress i link address
    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subId,
            ,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinator, subId, link, deployerKey);
    }

    // funkcija kojom fundiramo
    function fundSubscription(
        address vrfCoordinator,
        uint64 subId,
        address link,
        uint256 deployerKey
    ) public {
        console.log("Funding subscription: ", subId);
        console.log("Using VRF Coordinator: ", vrfCoordinator);
        console.log("On CHAIN ID: ", block.chainid);
        // proveravamo dal je local (na local koristimo mock) u suprotnom koristimo LinkToken
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

// pravimo contract gde dodajemo nove consumere
contract AddConsumer is Script {
    function addConsumer(
        address raffle,
        address vrfCoordinator,
        uint64 subId,
        uint256 deployerKey
    ) public {
        console.log("Funding subscription: ", subId);
        console.log("Using VRF Coordinator: ", vrfCoordinator);
        console.log("On CHAIN ID: ", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , uint64 subId, , ,uint256 deployerKey) = helperConfig
            .activeNetworkConfig();
        addConsumer(raffle, vrfCoordinator, subId, deployerKey);
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(raffle);
    }
}
