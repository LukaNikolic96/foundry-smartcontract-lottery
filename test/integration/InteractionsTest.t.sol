// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;


import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {CreateSubscription} from "../../script/Interactions.s.sol";

contract InteractionTest is Test {
   CreateSubscription public createSubscription;


   function setUp() public {
       createSubscription = new CreateSubscription();
   }

   function testCreateSubscriptionUsingConfig() public {
       uint64 subId = createSubscription.createSubscriptionUsingConfig();
       assertTrue(subId > 0, "Subscription ID should be greater than 0");
   }
}
