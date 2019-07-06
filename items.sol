pragma solidity ^0.4.25;

// Item management, use, and marketplace stuff
// One issue is automating item drops in a town. There's no way to automatically trigger a contract from within the chian, which means that I'll need some kind of cron-like service that has trusted access to the ccontract.
// Actually, most item stuff should be off chain or things will get slow and expensive really fast. I can have item generation off chain and then just do building alterations on chain
contract Items {
  struct Item {
      uint type;
  }
}
