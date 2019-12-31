pragma solidity ^0.4.25;

// This is a simple competition game where people will burn WRLD.
// After a certain amount of time has passed, the game will end with the next burn and the person who has burned the most WRLD will receive the total amount of TRX held by the contract.
// The next version will burn rather than return WRLD and it would be nice if it could restart automatically. I could even add a fund booster by requiring a small amount of TRX (10 or so) to register.

// Require registration by paying a certain number of TRX. Part of that fee goes to the pool and part goes to us.

// Convert mappings to include maps to rounds so I can restart the game.

contract Owned {
  address public owner;
  address public oldOwner;
  uint public tokenId = 1002567;
  uint lastChangedOwnerAt;
  constructor() {
    owner = msg.sender;
    oldOwner = owner;
  }
  modifier isOwner() {
    require(msg.sender == owner);
    _;
  }
  modifier isOldOwner() {
    require(msg.sender == oldOwner);
    _;
  }
  modifier sameOwner() {
    address addr = msg.sender;
    // Ensure that the address is a contract
    uint size;
    assembly { size := extcodesize(addr) }
    require(size > 0);

    // Ensure that the contract's parent is
    Owned own = Owned(addr);
    require(own.owner() == owner);
     _;
  }
  // Be careful with this option!
  function changeOwner(address newOwner) isOwner {
    lastChangedOwnerAt = now;
    oldOwner = owner;
    owner = newOwner;
  }
  // Allow a revert to old owner ONLY IF it has been less than a day
  function revertOwner() isOldOwner {
    require(oldOwner != owner);
    require((now - lastChangedOwnerAt) * 1 seconds < 86400);
    owner = oldOwner;
  }
}

contract Blacklist is Owned {
  mapping (address => bool) private blacklist;
  function isBlacklisted(address addr) public view returns (bool) {
    return blacklist[addr];
  }
  function setBlacklisted(address addr, bool bl) isOwner {
    blacklist[addr] = bl;
  }
}
contract Blacklistable is Owned {
  Blacklist list;
  modifier okay() {
    require(!list.isBlacklisted(msg.sender));
    _;
  }
  function setBlacklist(address addr) isOwner {
    list = Blacklist(addr);
  }
}
