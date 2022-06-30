//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract Casino {

  struct ProposedBet {
    address sideA;
    uint value;
    uint placedAt;
    bool accepted;   
  }    // struct ProposedBet


  struct AcceptedBet {
    address sideB;
    uint acceptedAt;
    uint randomBHash;
  }   // struct AcceptedBet

  struct SettlingBet {
    address sideA;
    address sideB;
    uint value;
    uint valA;
    uint valB;
    bool aTrue;
    bool bTrue;
  }

  // Proposed bets, keyed by the commitment value
  mapping(uint => ProposedBet) public proposedBet;

  // Accepted bets, also keyed by commitment value
  mapping(uint => AcceptedBet) public acceptedBet;

  mapping(uint => SettlingBet) public settlingBet;

  event BetProposed (
    uint indexed _commitment,
    uint value
  );

  event BetAccepted (
    uint indexed _commitment,
    address indexed _sideA
  );


  event BetSettled (
    uint indexed _commitment,
    address winner,
    address loser,
    uint value    
  );


  // Called by sideA to start the process
  function proposeBet(uint _commitment) external payable {
    require(proposedBet[_commitment].value == 0,
      "there is already a bet on that commitment");
    require(msg.value > 0,
      "you need to actually bet something");

    proposedBet[_commitment].sideA = msg.sender;
    proposedBet[_commitment].value = msg.value;
    proposedBet[_commitment].placedAt = block.timestamp;
    // accepted is false by default

    emit BetProposed(_commitment, msg.value);
  }  // function proposeBet


  // Called by sideB to continue
  function acceptBet(uint _commitment, uint _randomHash) external payable {

    require(!proposedBet[_commitment].accepted,
      "Bet has already been accepted");
    require(proposedBet[_commitment].sideA != address(0),
      "Nobody made that bet");
    require(msg.value == proposedBet[_commitment].value,
      "Need to bet the same amount as sideA");

    acceptedBet[_commitment].sideB = msg.sender;
    acceptedBet[_commitment].acceptedAt = block.timestamp;
    acceptedBet[_commitment].randomBHash = _randomHash;
    proposedBet[_commitment].accepted = true;

    emit BetAccepted(_commitment, proposedBet[_commitment].sideA);
  }   // function acceptBet

  function verifyA(uint _random) external {
    uint _commitment = uint256(keccak256(abi.encodePacked(_random)));
    
    require(proposedBet[_commitment].sideA == msg.sender, "Not a bet you placed or wrong value");
    require(proposedBet[_commitment].accepted, "Bet has not been accepted yet");

    settlingBet[_commitment].sideA = msg.sender;
    settlingBet[_commitment].valA = _random;
    settlingBet[_commitment].aTrue = true;
  }

  function verifyB(uint _commitment, uint _random) external {
    uint hashB = uint256(keccak256(abi.encodePacked(_random)));
    
    require(acceptedBet[_commitment].sideB == msg.sender, "Not a bet you placed or wrong value");
    require(proposedBet[_commitment].accepted, "Bet has not been accepted yet");
    require(acceptedBet[_commitment].randomBHash == hashB, "Incorrect number given");

    settlingBet[_commitment].sideB = msg.sender;
    settlingBet[_commitment].valB = _random;
    settlingBet[_commitment].bTrue = true;

  }
/*
    struct SettlingBet {
    address sideA;
    address sideB;
    uint value;
    uint valA;
    uint valB;
    bool aTrue;
    bool bTrue;
  }*/

  function settleUp(uint _commitment) external {
    address payable sideA = payable(settlingBet[_commitment].sideA);
    address payable sideB = payable(settlingBet[_commitment].sideB);
    uint valA = settlingBet[_commitment].valA;
    uint valB = settlingBet[_commitment].valB;
    uint value = settlingBet[_commitment].value;

    uint agreedRandom = valA ^ valB;

    require(settlingBet[_commitment].aTrue, "side A has not verified yet");
    require(settlingBet[_commitment].bTrue, "side B has not verified yet");

     if (agreedRandom % 2 == 0) {
      // sideA wins
      sideA.transfer(2*value);
      emit BetSettled(_commitment, sideA, sideB, value);
    } else {
      // sideB wins
      sideB.transfer(2*value);
      emit BetSettled(_commitment, sideB, sideA, value);      
    }

    delete proposedBet[_commitment];
    delete acceptedBet[_commitment];
    delete settlingBet[_commitment];

  }
}