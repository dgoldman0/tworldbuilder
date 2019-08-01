pragma solidity ^0.4.25;

// This faucet contract will be version 0.1 of WorldBuilder
// Aside from the basic drip feature, which requires going back to the site constantly, there is also a referral program and interest if the funds are left in the contract.
// Moreover, there is a prize fund that people will be entered into simply by performing the drip operation.
// In order to get a higher interest rate, people can pay TRX, which will help keep the contract funded, and will also give me a little bit of revenue. Boost will be from 0% up to 100 percentage point boost.

contract WorldFaucet {
  address parent = msg.sender;
  mapping (address => bool) public registered; // Is the user registered?
  mapping (address => address) public referrers; // Referrals
  mapping (address => uint) public balance;    // Currentl balance
  mapping (address => uint) public boosted;    // Total interest rate boost in TRX
  mapping (address => uint) public lastDrop;   // Last time at which drop was received
  uint public prizeFund;
  uint public prizeReserve;
  uint public dripsSinceLastPrize;
  uint public tokenId = 1002567;
  uint public reserved; // Amount reserved for balance, etc.
  uint public lastDrip; // When the last drip occurred
  uint public totalPlayers; // Total number of people who have registered
  uint public totalGiven;    // Total withdrawn less total added
  uint public boostTotal;  // Total amount given to boost interest
  bool isPrizeAvailable;
  event Registered(address user);
  event WonPrize(address user);

  // Update the balance of an address and add it to the reserved amount
  function _updateBalance(address addr, uint amount) {
      balance[addr] += amount;
      reserved += amount;
  }

  // Return how long until the user can take another drop
  function secondsToNextDrip() public view returns (uint) {
      uint diff = 300 - ((now - lastDrop[msg.sender]) * 1 seconds);
      if (diff < 0) return 0;
      return diff;
  }

  // How long it's been since a user has taken a drop, which also counts as the size of the drip
  function secondsSinceLastDrip() public view returns (uint) {
      return (now - lastDrip) * 1 seconds;
  }

  // To make this part more game like, the boost could be based on how much people have contributed in total. It would make it a competition.
  function boost() external payable {
    // The boost fee goes to the contract creator
    require(msg.value > 0, "You have to give TRX to boost.");
    require(registered[msg.sender], "You are not registered. To register, grab a drip from the faucet.");
    parent.transfer(msg.value);
    boosted[msg.sender] += msg.value;
    boostTotal += msg.value;
    // Increase the prize and prize pool by 10 times the amount of TRX used to boost
    prizeFund += 8 * msg.value;
    prizeReserve += 2 * msg.value;
  }

  function getMyBalance() public view returns (uint) {
      return balance[msg.sender];
  }

  // If a person wants to deposit funds to get interest, they can!
  function deposit() external payable {
    require(registered[msg.sender], "You are not registered. To register, grab a drip from the faucet.");
    require(msg.tokenid == tokenId, "You sent the wrong token.");
    _updateBalance(msg.sender, msg.tokenvalue);
    totalGiven = totalGiven - msg.tokenvalue;
  }

  function getBoost() public view returns (uint) {
    return _getBoost(msg.sender);
  }

  function _getBoost(address user) returns (uint) {
    // Calculate boost percentage, up to 100 percentage points
    // User Contribution % : Bonus
    // 100%   : 100%
    // 50%    : 99%
    // 25%    : 98%
    // 12.5%  : 97%
    // ...
    uint boost_amt = 0;
    if (boosted[user] > 0) {
      boost_amt = 100 - (boostTotal / boosted[user] - 1);
      if (boost_amt < 0) boost_amt = 0;
    }
    return boost_amt;
  }

  // Drip and at the same time calculate interest on stored funds
  // Adding some randomness would make it more game-like
  function drip(address referrerAddress) external {
      uint start = now; // Make sure interest, drip, and update all use the same time, since "now" can change during contract execution
      _register(referrerAddress);
      address user = msg.sender;

      uint boost_amt = _getBoost(user);

      // I use seconds to reduce rounding error. One thing to note is that this method updates the interest rate whenever a drip occurs.
      // What this situation means is that compounding occurs more frequently the more often the user ends up using the faucet.
      uint diff = (start - lastDrop[msg.sender]) * 1 seconds;
      require(diff > 300, "You have already gotten your drop for the alloted time!"); // Can only drip once every five minutes

      _updateBalance(user, balance[user] * (5 + boost_amt) * diff / 31557600 / 100);

      uint drop = (start - lastDrip) * 1 seconds;
      _updateBalance(user, max(2, drop));
      lastDrop[user] = start;

      // Give the referrer one WRLD as a bonus
      if (referrers[msg.sender] != 0x0) {
          _updateBalance(msg.sender, max(1, drop / 2));
      }

      // Add to prize fund
      prizeFund += max(drop * 2 / 30, 6);
      prizeReserve += max(drop / 30, 3);

      dripsSinceLastPrize++;
      lastDrip = start;
  }

  function max(uint a, uint b) private pure returns (uint) {
      return a > b ? a : b;
  }

  // Register the user in the database
  function _register(address referrerAddress) internal {
      if (!registered[msg.sender]) {
          require(referrerAddress != msg.sender);
          if (registered[referrerAddress]) {
              referrers[msg.sender] = referrerAddress;
          }

          totalPlayers++;
          registered[msg.sender] = true;
          emit Registered(msg.sender);
      }
  }

  // If the prize is up for grabs, give it!
  function getPrize() external {
    require(registered[msg.sender], "You are not registered. To register, grab a drip from the faucet.");
    if (checkPrizeAvailable() && prizeFund > 0)
      _getPrizeFund(msg.sender);
  }

  // If the current drips since last prize is less than 1,000 less twice the number of seconds since the last drip, give prize.
  function checkPrizeAvailable() public view returns (bool) {
    if (isPrizeAvailable) return true;
    isPrizeAvailable = dripsSinceLastPrize > (1000 - 2 * ((now - lastDrip) * 1 seconds));
    return isPrizeAvailable;
  }

  // Return the available balance of WRLD, taking into account the amount that's reserved and in the prize pools
  function getAvailableBalance() public view returns (uint) {
    return address(this).tokenBalance(tokenId) - reserved - prizeFund - prizeReserve;
  }

  // Pull tokens from the contract
  function withdrawTokens() external {
      require(registered[msg.sender], "You are not registered. To register, grab a drip from the faucet.");
      uint amount = balance[msg.sender];
      // If there aren't enough tokens available, give what is available.
      uint max_amt = address(this).tokenBalance(tokenId);
      if (max_amt < amount)
        amount = max_amt;

      if (amount > 0) {
        balance[msg.sender] = balance[msg.sender] - amount;
        msg.sender.transferToken(amount, tokenId);
        reserved = reserved - amount;
        totalGiven += amount;
      }
  }

  function _getPrizeFund(address user) {
      uint amount = prizeFund;
      isPrizeAvailable = false;
      prizeFund = prizeReserve;
      prizeReserve = 0;
      dripsSinceLastPrize = 0;
      _updateBalance(user, amount);
      emit WonPrize(user);
  }

  function register(address referrerAddress) external {
      _register(referrerAddress);
  }

  // Fallback function
  function () external payable {}

  // Functions to pull tokens and TRX that might accidentally be sent to the contract address. The only token that cannot be pulled, even by the contract creator, is WRLD.

  // Transfer all tron in the account into the contract creator's account
  function superWithdrawTRX() external {
    require(msg.sender == parent, "This account is not authorized to use superuser functions.");
    msg.sender.transfer(address(this).balance);
  }

  // Transfer total amount of any token that might have accidentally been added to the contract, except WRLD so that the contract creator cannot pull WRLD from the game and kill it, under most conditions...
  function superWithdrawTRC(uint tid) external {
    require(msg.sender == parent, "This account is not authorized to use superuser functions.");

    // If the contract is inactive for over ONE WEEK, then the parent address can withdraw WRLD!
    require(tid != tokenId || (now - lastDrip) * 1 seconds > 604800, "You canot withdraw WRLD!");
    msg.sender.transferToken(address(this).tokenBalance(tid), tid);
  }
}
