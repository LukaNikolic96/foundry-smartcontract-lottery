// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "../../lib/forge-std/src/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    /* Events */
    event EnteredRaffle(address indexed player);

    // prvo kreiramo setup i koristimo deployraffle da bi iskoristili raffle iz taj contract
    // takodje i pravimo nove igrace s koji ce vrsimo testove
    Raffle raffle;
    HelperConfig helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link,

        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE); // cheat code da damo tokene playeru
    }

    // testiramo da raffle krece uvek iz open state
    function testRaffleInitializeStateInOpen() public view {
        //Raffle.RaffleState.OPEN - ovo znaci da na svakom raffle contractu sto sadrzi rafflestate uzme OPEN vrednost
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /* enterRaffle test */
    function testingRaffleWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act/ Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughETHSent.selector);
        raffle.enterRaffle();
    }

    // test if raffle records player when they enter
    function testRaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: entranceFee}();
        // Assert
        address getRafflePlayer = raffle.getPlayer(0);
        assert(getRafflePlayer == PLAYER);
    }

    // test events on entrance if emmits - we must make events in our test contract as I did above (same as in Raffle.sol)
    function testEmitsOnEntranceEvent() public {
        // Arrange
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        // Act
        emit EnteredRaffle(PLAYER);
        // Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    // test to see if you can't enter when raffle is calculating
    function testCantEnterWhenCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        // manipulisemo vremenske intervale
        vm.warp(block.timestamp + interval + 1);
        // manipulisemo blokove
        vm.roll(block.number + 1);

        // ACT/ Assert
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /* CheckUpkeep testovi */

    // testiramo dal ce da vrati false ako nema balance
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // prvo stavljamo tj manipulisemo vreme i blokovima da budu kako treba
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    // testiramo dal raffle vraca false ako nije open
    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public {
        // prvo stavljamo u calculating stanje
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(raffleState == Raffle.RaffleState.CALCULATING);
        assert(!upkeepNeeded);
    }

    // testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed
    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act/ Assert
        (bool success, ) = address(raffle).call(
            abi.encodeWithSignature("performUpkeep()")
        );
        require(!success, "Expected performUpkeep() to revert");
    }

    // testcheckUpkeepReturnsTrueWhenParametersAreGood

    function testcheckUpkeepReturnsTrueWhenParametersAreGood() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assertTrue(upkeepNeeded);
    }

    /* performUpkeep tests */

    // provera da performUpkeep moze da radi samo kad je checkUpkeep true
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.timestamp + 1);

        // Act/ Assert
        raffle.performUpkeep("");
    }

    // test dal performUpkeep revertuje ako je checkUpkeep false
    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        // stavljamo odredjeni parametri koji se nalaze u performUpkeep da ih prikaze tj ukljuci
        uint256 currentBalance = 0;
        uint256 playerLength = 0;
        uint256 raffleState = 0;

        // Act / assert
        // expectRevert ocekuje da ce naredna u ovom slucaju performUpkeep transakcija da failuje i da revertuje
        // sa odredjenim error kodom (Raffle__UpkeepNotNeeded u ovom slucaju) i sa odredjenim parametrima
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                playerLength,
                raffleState
            )
        );

        raffle.performUpkeep("");
    }

    // mali modifier da ne kucamo stalno ovo
    modifier rafflePrankAndTime() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.timestamp + 1);
        _;
    }

    // testiramo requestId event
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        rafflePrankAndTime
    {
        // Arange je U modifier
        // Act
        // ovo kaze VM-u da snima sve evente i kasnije mozemo da im pristupimo ako ocemo
        vm.recordLogs();
        raffle.performUpkeep(""); // ova funkcija ce da emituje event koji nam treba u ovom slucaju requestId

        // ovo je specijalan tip u foundry i daje nam vrednosti svih eventa koji su emitovani u odredjenoj funkciji(performUpkeep u ovom slucaju)
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // svi logovi su bytes32
        // entries 1 jer je 0 event onaj iz mock koji se emituje zbog requestRandomWords
        // takodje je i topic 1 a ne 0 jer iako je prva za event koji mi gledamo nije prva u celokupnu funkciju tj zato sto nas event
        // takodje nije prvi event
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState raffleState = raffle.getRaffleState();

        // uslov da je vece od 0 znaci da je emitovan i stvoren taj event i da je njegovo ime vece od 0
        assert(uint256(requestId) > 0);
        // raffle state koristimo da bi se uverili da je state u calculating modu tj da racuna i bira pobednika
        assert(uint256(raffleState) == 1);
    }

    /* FULFILL RANDOM WORDS TEST */

    // dodajemo modifier da skipuje fork ako smo na testnet
    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    // test da fulfillRandomWords moze da bude pozvan samo posle performUpkeep
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public rafflePrankAndTime skipFork {
        /* ovde koristimo fuzz test i on automatski kreira nasumicne brojeve (u ovom slucaju randomRequestId) i uz pomoc njega
        proveravamo dal ce uvek da revertuje , sto znaci da pre nego sto je pozvana fulfillRandomWords funkcija pre nje nije izvrsena
        performUpkeep funkcija */

        vm.expectRevert("nonexistent request");
        // pozivamo fulfillRandomWords iz mock i kad pogledas njoj trebaju 2 parametra uint256 _requestId(u nasem testu to je randomRequestId)
        // i adresa consumera kod nas je to adresla raffle iz Raffle contracta imas gore Raffle raffle;
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    // this will bi big test where we will test pick a winner, reset balance and send money to the winner
    function testFulfillRandomWordsPicksAWinnerResetsAndSendMoney()
        public
        rafflePrankAndTime
        skipFork
    {
        // Arrange
        // dodajemo dodatne igrace
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i)); // address(2), address(3), etc...
            hoax(player, STARTING_USER_BALANCE); // pretvaramo se da smo player i da imamo neki pocetni kapital (balans)
            raffle.enterRaffle{value: entranceFee}();
        }
        // nagrada
        uint256 prize = entranceFee * (additionalEntrants + 1);

        // Act
        // prvo testiramo da dobijemo requestId sto cemo da koristimo u fullfillRandomWords ispod
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // da dobijemo last time stamp
        uint256 previousTimeStamp = raffle.getLastTimeStamp();

        // pretvaramo se da smo chainlink vrf da dobijemo nasumican broj i da se izabere pobednik
        // znamo da uvek log loguje u bytes32 ali fulfillRandomWords koristi uint256 pa zato samo stavili uint256 umesto bytes32
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        // proveravamo da raffle state bude u 0 polozaju tj u OPEN state
        assert(uint256(raffle.getRaffleState()) == 0);
        // proveravamo da poslednji dobitnik nije adresa 0 nego neka od ove nove sto smo kreirali u for petlju
        assert(raffle.getRecentWinner() != address(0));
        // proveravamo da li je skup igraca resetovan odnosno jednak 0
        assert(raffle.getLengthOfPlayers() == 0);
        /* The assert(previousTimeStamp < raffle.getLastTimeStamp()) line is checking if the previousTimeStamp 
        (which represents the time when the raffle started) is less than the current time (raffle.getLastTimeStamp()).
        So, if previousTimeStamp is 1000 (the raffle started at this time), and a player tries to enter at time 1035,
         the function will pass because 1000 is less than 1035.
        However, if a player tries to enter at time 990, the function will fail because 1000 is not less than 990.
         The assert statement will throw an error and stop the execution of the program. */
        assert(previousTimeStamp < raffle.getLastTimeStamp());
        // proveravamo dali se novac prebacio odnosno da je pobednikov balans jednak sa ovom jednacinom
        assert(
            raffle.getRecentWinner().balance ==
                prize + STARTING_USER_BALANCE - entranceFee
        );
    }
}
