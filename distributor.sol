// This contract will distribute funds to different places so I can balance out how funds are put into various games.

pragma solidity ^0.4.25;

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

contract Distributor is Owned {
  struct Setting {
    bool added;
    uint weight;
  }
  uint totalWeight = 0;
  mapping (address => Settings) public settings;
  address[] addresses;

  function setAddressWeight(address addr, uint weight) isOwner {
    Settings setting;
    if (!settings[addr].added) {
      addresses.push(addr);
      setting = Setting(true, weight);
      totalWeight += weight;
    } else {
      setting = settings[addr];
      totalWeight -= setting.weight;
      setting.weight = weight;
      totalWeight += weight;
    }
  }

  function sendTRX() public payable {
    require(totalWeight > 0);
    for (uint i = 0; i < addresses.length; i++) {
      address addr = addresses[i];
      if (addr != 0) {
        Setting setting = settings[address];
        if (setting.weight > 0);
          addr.transfer(msg.value * setting.weight / totalWeight);
      }
    }
    owner.transfer(address(this).balance); // If there's residual from rounding, just send it to owner address
  }
}
