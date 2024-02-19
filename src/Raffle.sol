// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title Raffle Contract
 * @author Luka Nikolic
 * @notice This contract is for creating a simple raffle
 * @dev Implements Chainlink VRFv2
 */

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Raffle is VRFConsumerBaseV2 {
    /* ERRORS */
    error Raffle__NotEnoughETHSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    /* TYPE DECLARATIONS */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* STATE VARIABLES */
    uint256 private immutable i_entranceFee;
    // mesto gde cuvamo sve one koji ucestvuju i stavljamo payable jer ce treba da platimo nekom od njih i njih cuvamo u storage
    address payable[] private s_players;
    // invertal kad da se trigeruje izvlacenje
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /* EVENTS */
    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    /* FUNCTIONS */
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() external payable {
        // umesto require ce koristimo if i error jer su vise gas efficient
        //require(msg.value >= i_entranceFee, "Need more ETH!");
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHSent();
        }
        // proferavamo da li je raffle open tj dal nije u procesu izracunavanja dobitnika
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        // ovo ubacuje adresu onog ko ucestvuje u array i stavljamo da je ta adresa payable da moz joj se plati i da je owner (msg.sender) inicirao
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    // checkupkeep odredjuje kad pobednik treba da bude izabran
    /**
     * @dev Ovu funkciju Chainlink Automatione nodes poziva to vidi dal je vreme da izabere novog dobitnika
     * Sledece stvari moraju da budu true:
     * 1. Vremensi interval izmedlju raffle runs je proso (vreme koje smo mi odredili izmedju dva dobitnika)
     * 2. Raffle je u OPEN state
     * 3. Kontract sadrzi ETH  (igrace- players)
     * 4. Subskripcija je fundovama sa LINK tokenima
     */
    function checkUpkeep(
        bytes memory /*checkData*/
    ) public view returns (bool upkeepNeeded, bytes memory /*performData*/) {
        //1. proveravamo dal je dovoljno vremena proslo od poslednjeg pobednika
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        // 2. raffle u open state
        bool isOpen = RaffleState.OPEN == s_raffleState;
        // 3.da contract sadrzi ETH odnosn igrace
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0"); // 0x0 is blank bytes object
    }

    // /* Na koji nacin zelimo da se obavi pick a winner:
    // 1. Da dobijemo random broj✅
    // 2. Da iskoristimo taj random broj da izaberemo pobednika✅
    // 3. Da se pickWinner automatski pozove kad pobednik bude izabran - zbog automatike menjamo pickWinner u performUpkeep*/
    // function pickWinner() public {
    //     // pre nego da posaljemo request stavljamo da je rafflestate u calculate modu da ne mogu da se ubace novi igraci tokom tog procesa
    //     s_raffleState = RaffleState.CALCULATING;
    //     /* Getting a random number is a 2 tx process:
    //     1.Request the random number generator
    //     2. Get the random number */
    //     // sve ovo iz requestId se takodje nalazi u constructor
    //     uint256 requestId = i_vrfCoordinator.requestRandomWords( // COORDINATOR (i_vrfCoordinator) je chainlink coordinator adresa i on kordinira nasim requestima
    //         i_gasLane, // ovo je gas lane (prethodno keyHash)
    //         i_subscriptionId, // ovo je ID koji smo fundirali s LINK tokeni
    //         REQUEST_CONFIRMATIONS, // to je block confirmations odnosno kolko bloka da prodje da verujemo da je nas broj dobar
    //         i_callbackGasLimit, // ovo je limit kojim osiguravamo da ne potrosimo previse gasa po pozivu
    //         NUM_WORDS // broj reci ili u ovom slucaju broj nasumicnih brojeva (numWords)
    //     );
    // }
    function performUpkeep(bytes calldata /*performData */) external {
        // prvo pozivamo checkupkeep da vidimo dal je true
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRaffleWinner(requestId);
    }

    //2. GET RANDOM NUMBER function
    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        // kad dobijemo pobednika prebacujemo rafflestate u open
        s_raffleState = RaffleState.OPEN;

        // zatim resetujemo array s novim igracima
        s_players = new address payable[](0);
        // update time stamp so it start calculating againg
        s_lastTimeStamp = block.timestamp;
        // emitujemo event s most recent winner da se zna da je pobednik izabran
        emit WinnerPicked(winner);
        // s ovim uplacujemo nagradu dobitniku
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /* Getter Functions - tu pisemo geter funkcije za sve private komponente*/
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns(RaffleState){
        return s_raffleState;
    }

    // funkcija da vidimo adrese igraca
    function getPlayer(uint256 indexOfPlayer) external view returns(address){
        return s_players[indexOfPlayer];
    }
    // funkcija da dobijemo adresu poslednjeg pobednika
    function getRecentWinner() external view returns(address){
        return s_recentWinner;
    }

    // funkcija da dobijemo duzinu niza kolko ima igraca
    function getLengthOfPlayers() external view returns(uint256){
        return s_players.length;
    }

    // funkcija da dobijemo poslednji time stamp
    function getLastTimeStamp() external view returns(uint256){
        return s_lastTimeStamp;
    }
}

/* CEI: Checks, Effects, Interactions 
1. Checks - prvo stavljamo checks elemente tu spadaju require, (if i errors) zato sto je gas efficient, u smislu bolje je to da stavimo
na pocetak funkcije jer ako nesta ne valja da nam odma revertuje i izbaci gresku umesto da prvo isprati i odradi ceo kod pa tek na kraj izbaci gresku
2. Effects (nas contract) - u to spada ostatak funkcije koji ima  razlicite uloge tj zadatke koje treba da uradi (ex:
uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        eventi i tako dalje...)
3. Interactions (sa drugim contractima) - ex:
(bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        interaction je jer salje nagradu na drugi contract koji nije nas*/
