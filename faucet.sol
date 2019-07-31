pragma solidity ^0.4.25;

// This faucet contract will be version 0.1 of WorldBuilder
// Aside from the basic drip feature, which requires going back to the site constantly, there is also a referral program and interest if the funds are left in the contract.
// Moreover, there is a prize fund that people will be entered into simply by performing the drip operation.
// In order to get a higher interest rate, people can pay TRX, which will help keep the contract funded, and will also give me a little bit of revenue. Boost will be from 0% up to 100 percentage point boost.
contract WorldFaucet {
  address parent = msg.sender;
  mapping (address => bool) public registered;  // Is the user registered?
  mapping (address => uint) public balance;     // Currentl balance
  mapping (address => uint) public boosted;     // Total interest rate boost in TRX
  mapping (address => uint) public lastBonus;   // Last time at which interest was received
  uint public prizeFund;
  uint public prizeReserve;
  uint public tokenId = 1002567;
  uint reserved; // Amount reserved for balance, etc.
  uint lastDrip; // When the last drip occurred
  uint totalInvestors; // Total number of people who have registered
  uint totalGiven;    // Total withdrawn less total added

  // To make this part more game like, the boost could be based on how much people have contributed in total. It would make it a competition.
  function boost() external {
    // Don't boost if the result would push the amount over 100%
    require(boosted[msg.sender] + msg.value < 1000, "The boost would be above the allowed 100%.");

    // The boost fee goes to the contract creator
    parent.transfer(msg.value);

    boosted[msg.sender] += msg.value;
  }

  // Update the balance of an address and add it to the reserved amount
  function _updateBalance(address addr, uint amount) {
      balance[addr] += amount;
      reserved += amount;
  }

  function getBalance() external {
      return balance[msg.sender];
  }

  // If a person wants to deposit funds to get interest, they can!
  function deposit() external {
    require(registered[msg.sender], "You are not registered. To register, grab a drip from the faucet.");
    require(msg.tokenid == tokenId, "You sent the wrong token.");
    _updateBalance(msg.sender, msg.tokenvalue);
    totalGiven = totalGiven - msg.tokenvalue;
  }

  // Drip and at the same time calculate interest on stored funds
  // Adding some randomness would make it more game-like
  function drip(referrerAddress) external {
      uint start = now; // Make sure interest, drip, and update all use the same time, since "now" can change during contract execution
      _register(referrerAddress);
      lastDrip = now;
      address user = msg.sender;

      // Increase the interest rate by one percentage point per 10 TRX, up to 100%
      uint boost = boosted[user] / 10;

      // This shouldn't be necessary because boost won't allow the amount to go above 100%, but just in case.
      if (boost > 100) boost = 100;

      // I use seconds to reduce rounding error. One thing to note is that this method updates the interest rate whenever a drip occurs.
      // What this situation means is that compounding occurs more frequently the more often the user ends up using the faucet.
      uint diff = (start - lastDrip[msg.sender]) * 1 seconds
      _updateBalance(user, balance[user] * (5 + boost) * diff / 31557600 / 100);

      // Perform drip
      if (diff > 300) {
        _updateBalance(user, 2);
        lastDrip[user] = start;
      }

      // Give the referrer one WRLD as a bonus
      if (referrers[msg.sender] != 0x0) {
          _updateBalance(msg.sender, 1);
      }

      // Add to prize fund
      prizeFund += 9;
      prizeReserve += 1;
  }

  // Register the user in the database
  function _register(address referrerAddress) internal {
      if (!registered[msg.sender]) {
          require(referrerAddress != msg.sender);
          if (registered[referrerAddress]) {
              referrers[msg.sender] = referrerAddress;
          }

          totalInvestors++;
          registered[msg.sender] = true;
          emit Registered(msg.sender);
      }
  }

  function availableBalance() public view returns (uint) {
    return address(this).tokenBalance(tokenId) - reserved;
  }

  // Pull tokens from the contract
  function withdrawTokens() payable external {
      uint amount = balance[msg.sender];
      // If there aren't enough tokens available, give what is available.
      uint max = address(this).tokenBalance(tokenId);
      if (max < amount)
        amount = max;

      if (amount > 0) {
        balance[msg.sender] = 0;
        msg.sender.transferToken(amount, tokenId);
        reserved = reserved - amount;
        totalGiven += amount;
      }
  }

  // Obtained from the tronbuild.fun contract
  function allowGetPrizeFund(address user) public view returns (bool) {
      return lastInvestor == user && ((now - lastDrip) * 1 seconds > 60) && prizeFund > 0;
  }

  function getPrizeFund() external {
      require(allowGetPrizeFund(msg.sender));
      // I think this order is needed prevent people from getting the prize multiple times
      uint amount = prizeFund;
      prizeFund = prizeReserve;
      prizeReserve = 0;
      _updateBalance(msg.sender, amount);
  }

  function register(address referrerAddress) external notContract {
      _register(referrerAddress);
  }
}
