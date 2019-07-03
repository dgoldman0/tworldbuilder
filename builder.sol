pragma solidity ^0.4.25;

// This application is based off of the tronbuild.fun application
// What is needed to make this game more reasonable, among other things, is the ability to transfer buildings back and forth
// I'll need to create the framework for a market
// Should I use 0x0 or address(0)?
// Maybe change it so that the game won't start until a certain number of people register?
// I can help fund the game with ads
// Pre-start signup bonuses should also be added

// It would also be nice to have building types with more variation so that they can become collectable. Instead of using prices as the building types, something else would be needed.

contract WorldBuilder {
    address support = msg.sender;
    address private lastSender;
    address private lastOrigin;
    uint public totalFrozen;
    uint public tokenId = 0x0;

    uint public prizeFund;
    uint public prizeReserve;
    address public lastInvestor;
    uint public lastInvestedAt;

    uint public totalInvestors;
    uint public totalInvested;

    // records registrations
    mapping (address => bool) public registered;
    // records amounts invested
    mapping (address => mapping (uint => uint)) public invested;
    // records blocks at which investments were made
    mapping (address => uint) public atBlock;
    // records referrers
    mapping (address => address) public referrers;
    // records buildings
    mapping (address => mapping (uint => uint)) public buildings;
    // frozen tokens
    mapping (address => uint) public frozen;

    event Registered(address user);

    modifier notContract() {
        lastSender = msg.sender;
        lastOrigin = tx.origin;
        require(lastSender == lastOrigin);
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == support);
        _;
    }

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

    function buyBuilding(address referrerAddress) external payable {
        require(totalInvestors > 25);
        require(_isValidType(msg.value));

        buildings[msg.sender][msg.value]++;
        prizeFund += msg.value * 6 / 100;
        prizeFund += msg.value * 1 / 100;

        // This would be used to collect profits... without this, only profiting could come from playing!
        support.transfer(msg.value * 2 / 100);

        _register(referrerAddress);

        // Looks like the referrer gets a 10% finder fee for the first purchase
        if (referrers[msg.sender] != 0x0) {
            referrers[msg.sender].transfer(msg.value / 10);
        }

        lastInvestor = msg.sender;
        lastInvestedAt = block.number;

        getAllProfit();

        invested[msg.sender][msg.value] += msg.value;
        totalInvested += msg.value;

        msg.sender.transferToken(msg.value, tokenId);
    }

    function getProfitFrom(address user, uint price, uint percentage) internal view returns (uint) {
        return invested[user][price] * percentage / 100 * (block.number - atBlock[user]) / 864000;
    }

    function getAllProfitAmount(address user) public view returns (uint) {
        return
            getProfitFrom(user, 50000000, 92) +
            getProfitFrom(user, 100000000, 93) +
            getProfitFrom(user, 200000000, 95) +
            getProfitFrom(user, 500000000, 98) +
            getProfitFrom(user, 1000000000, 102) +
            getProfitFrom(user, 5000000000, 107) +
            getProfitFrom(user, 10000000000, 113) +
            getProfitFrom(user, 100000000000, 120);
    }

    function getAllProfit() internal {
        if (atBlock[msg.sender] > 0) {
            uint max = (address(this).balance - prizeFund) * 9 / 10;
            uint amount = getAllProfitAmount(msg.sender);

            if (amount > max) {
                amount = max;
            }

            if (amount > 0) {
                msg.sender.transfer(amount);
            }
        }

        atBlock[msg.sender] = block.number;
    }

    function getProfit() external {
        getAllProfit();
    }

    function allowGetPrizeFund(address user) public view returns (bool) {
        return lastInvestor == user && block.number >= lastInvestedAt + 1200 && prizeFund > 0;
    }

    function getPrizeFund() external {
        require(allowGetPrizeFund(msg.sender));
        msg.sender.transfer(prizeFund);
        prizeFund = reserveFund;
        reserveFund = 0;
    }

    function register(address referrerAddress) external notContract {
        _register(referrerAddress);
    }

    // Should I keep token freezing? Not sure. If so, maybe I should give interest in tokens...
    function freeze() external payable {
        require(msg.tokenid == tokenId);
        require(msg.tokenvalue > 0);
        frozen[msg.sender] += msg.tokenvalue;
        totalFrozen += msg.tokenvalue;
    }

    function unfreeze() external {
        totalFrozen -= frozen[msg.sender];
        msg.sender.transferToken(frozen[msg.sender], tokenId);
        frozen[msg.sender] = 0;
    }

    // Not sure what this is for...
    function () external payable onlyOwner {

    }

    // Data structure for sale
    struct SaleListing {
        uint type;  // Building type
        uint qnt;   // Total quantity for sale
        uint price; // The per item price
        bool cancelled; // Was the sale cancelled?
        address buyer; // The address of the buyer, if the items have been sold
    }
    // Listed items for sale
    mapping (address => mapping (uint => SaleListing)) public forSale;
    mapping (address => uint) public saleCount; // Keep track of how many sales were made for next ID

    // Freeze for sale items: I could also include a small TRX fee here which could help fund the system
    function listBuildings(uint type, uint qnt, uint price) external payable {
        require(_isValidType(type) && buildings[msg.sender][type] >= qnt);
        uint fee = (qnt * price) / 100; // Charge a 1% TRX fee for listing
        require(msg.value == fee);
        buildings[msg.sender][type] -= qnt;
        // Add to sale list
        SaleListing sale = SaleListing(type, qnt, price, false, address(0));
        forSale[msg.sender][saeCount[msg.sender]] = sale;
        saleCount[msg.sender]++;
    }

    // Cancel an existing listing
    function cancelListing(uint listingId) external {
      SaleListing listing = forSale[msg.sender][listingId];
      require(listing != 0x0 && !listing.cancelled && listing.buyer == address(0)); // If it's already cancelled, I guess I could just leave it alone, but I think it should fail correctly if there's already a cancellation
      listing.cancelled = true;
    }

    // Buy a certain number of buildings from the seller
    function buyBuildings(address seller, listingId) external payable {
        require(block.number >= 10515592);
        require(msg.tokenid == tokenId);
        SaleListing sale = forSale[seller][listingId];
        require (sale != 0x0) && !sale.cancelled && sale.buyer == address(0) && sale.qnt * sale.price == msg.tokenValue);
        // Calculate fee
        uint fee = msg.tokenValue * 2 / 100; // Charge a 2% WORLD fee for buying
        // Transfer buildings
        buildings[msg.sender][sale.type] += sale.qnt;
        sale.buyer = msg.sender;
        // Transfer WORLD
        seller.transferToken(msg.tokenValue - fee, tokenId);
    }

    // Preregistration function which gives out bonuses and helps move the game to the starting position
    function preRegister(address referrerAddress) external {
      require(referrerAddress != msg.sender);
      require(!registered[msg.sender]);
      _register(referrerAddress);
      // Give out presale bonuses
      msg.sender.transferToken(1000);
      if (referrerAddress != 0x0) referrerAddress.transferToken(1000);
    }

    // Helper functions
    function _isValidType(uint type) internal {
      return(type == 50000000 || type == 100000000 || type == 200000000 || type == 500000000
        || type == 1000000000 || type == 5000000000 || type == 10000000000 || type == 100000000000);
    }
}
