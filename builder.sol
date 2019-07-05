pragma solidity ^0.4.25;

// This application is based off of the tronbuild.fun application
// What is needed to make this game more reasonable, among other things, is the ability to transfer buildings back and forth
// I'll need to create the framework for a market
// Should I use 0x0 or address(0)?
// Maybe change it so that the game won't start until a certain number of people register?
// I can help fund the game with ads
// Pre-start signup bonuses should also be added

// It would also be nice to have building types with more variation so that they can become collectable. Instead of using prices as the building types, something else would be needed.
// I should also make sure that there are tokens to give out...
// Should buidlings last forever or should they decay like in real life? In that case, a repair fee in WORLD could be used to keep the thing in top condition.
// If I really wanted to get fancy, I could even have "towns" and whatnot.

// The current setup does not send any information back with REQUIRE. It probably should. Fail gracefully damn it!

// Contract
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

    // Work towards making buildings non-fungible
    enum BuildingType {Cart, Boutique, Shop, Mall, Bank, Skyscraper, Powerplant, Resort};
    enum BuildingCondition {Pristine, VeryGood, Good, Fair, Poor, Derelict}
    // Each building should be unique
    struct Building {
        BuildingType type;
        uint id;
        BuildingCondition condition;
        uint townId;
    }
    struct Town {
        string name;
        address owner;
        uint taxRate; // This can range from 0% to 50%
        uint profits;
    }
    struct Home {
        address owner;
        string properties;
    }
    // records registrations
    mapping (address => bool) public registered;
    // Homes
    mapping (address => Home) public homes;
    // Thw Towns
    mapping (uint => Town) public towns;
    // records amounts invested
    mapping (address => mapping (uint => uint)) public invested;
    // records blocks at which investments were made
    mapping (address => uint) public atBlock;
    // records referrers
    mapping (address => address) public referrers;
    // lists whether a user is the owner of a building or not
    mapping (address => mapping (uint => bool)) public ownership;
    // List of all buildings
    mapping (uint => Building) public buildings;
    // Total number of buildings: used for ID as well
    uint public buildingCount;
    // frozen tokens
    mapping (address => uint) public frozen;

    // Item stuff
    mapping (address => mapping (uint => uint)) public inventory;

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
    // Do initial setup
    constructor() public () {
        // Create the base town where everything will be built at first
        Town ourTown = Town("Our Town", support, 3, 0);
        _addTown(ourTown);
    }

    function _register(address referrerAddress) internal {
        if (!registered[msg.sender]) {
            require(referrerAddress != msg.sender);
            if (registered[referrerAddress]) {
                referrers[msg.sender] = referrerAddress;
            }

            totalInvestors++;
            registered[msg.sender] = true;
            // Create a home for the person
            Home home = Home(msg.sender, "0000000000");
            emit Registered(msg.sender);
        }
    }

    function buyBuilding(address referrerAddress) external payable {
        require(totalInvestors > 25);
        require(_isValidType(msg.value));

        // This needs to be totally replaced with the new building format
        buildings[msg.sender][msg.value]++;
        prizeFund += msg.value * 6 / 100;
        prizeFund += msg.value * 1 / 100;

        // This would be used to collect profits... without this, only profiting could come from playing!
        // support.transfer(msg.value * 2 / 100);
        // How will we get profits instead? Simple: the initial town will have a 3% tax rate

        _register(referrerAddress);

        // Looks like the referrer gets a 10% finder fee for the first purchase
        if (referrers[msg.sender] != 0x0) {
            referrers[msg.sender].transfer(msg.value / 10);
        }

        lastInvestor = msg.sender;
        lastInvestedAt = block.number;

        // This is used to make profit calculations easier. I guess I'll leave it as is...
        // I think this should be called BEFORE the building is purcahsed though!
        getAllProfit();

        invested[msg.sender][msg.value] += msg.value;
        totalInvested += msg.value;

        msg.sender.transferToken(msg.value, tokenId);
    }

    // This function is necessary to calculate the current profit for a given building, but it's still using the old value method
    // Does not calculate taxes and I accidentally removed this from profit calculation which is necessary!
    function getProfitFrom(address user, uint price, uint percentage) internal view returns (uint) {
        return invested[user][price] * percentage / 100 * (block.number - atBlock[user]) / 864000;
    }

    // Need to change this so it returns profit and taxes in one shot
    function getAllProfitAmount(address user) public view returns (uint) {
      // Loop through all buildings
      uint cnt = buildings[user].length;
      uint total = 0;
      for (uint i = 0; i < cnt; i++) {
        Building cur = buildings[user][i];
        total += _typeToAmount(cur.type) * _getProfitForType(cur.type) * _getConditionModifier(cur.condition) / 100;
      }
      return total;
    }

    // Does not currently calculate taxes
    function getAllProfit() internal {
        if (atBlock[msg.sender] > 0) {
            uint max = (address(this).balance - prizeFund - reserveFund) * 9 / 10;
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

    // This is a basic callback function.
    function () external payable onlyOwner {

    }

    // Data structure for sale
    struct SaleListing {
        uint buildingId;
        uint price; // The per item price
        bool cancelled; // Was the sale cancelled?
        address buyer; // The address of the buyer, if the items have been sold
    }
    // Listed items for sale
    mapping (address => mapping (uint => SaleListing)) public forSale;
    mapping (address => uint) public saleCount; // Keep track of how many sales were made for next ID
    // Freeze for sale items: I could also include a small TRX fee here which could help fund the system
    // Doesn't work with new building model
    function listBuilding(uint buildingId, uint price) external {
        require(_ownsBuilding(buildingId));
        getAllProfit(); // Clear profits for easier calculation
        // Remove from ownership and add to listing

        // Add to sale list
        SaleListing sale = SaleListing(buildingId, price, false, address(0));
        forSale[msg.sender][saeCount[msg.sender]] = sale;
        saleCount[msg.sender]++;
    }

    // Cancel an existing listing
    function cancelListing(uint listingId) external {
      SaleListing listing = forSale[msg.sender][listingId];
      require(listing != 0x0 && !listing.cancelled && listing.buyer == address(0)); // If it's already cancelled, I guess I could just leave it alone, but I think it should fail correctly if there's already a cancellation
      listing.cancelled = true;
      // Return buidling to owner
      // ...
    }

    // Buy a certain number of buildings from the seller
    // Doesn't work with new building model
    function buyFromMarket(address seller, listingId) external payable {
        require(totalInvestors > 25, "The game hasn not started!");
        require(msg.tokenid == tokenId, "Wrong token!");
        SaleListing sale = forSale[seller][listingId];
        require (sale != 0x0) && !sale.cancelled && sale.buyer == address(0) && sale.price == msg.tokenValue, "Invalid sale parameters...");
        getAllProfit();
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
    // I could be lazy and use the fact that enums right now just treat the value as an uint so cart == 0, resort == 7, but...
    function _typeToAmount(BuildingType type) internal {
        if (type == BuildingType.Cart) {
            return 50000000;
        } else if (type == BuildingType.Boutique){
            return 100000000;
        } else if (type == BuildingType.Shop) {
            return 200000000;
        } else if (type == BuildingType.Mall) {
            return 500000000;
        } else if (type == BuildingType.Bank) {
            return 1000000000;
        } else if (type == BuildingType.Skyscraper) {
            return 5000000000;
        } else if (type == BuildingType.Powerplant) {
            return 10000000000;
        } else if (type == BuildingType.Resort) {
            return 100000000000;
        }
    }

    function _amountToType(uint amount) internal {
        if (amount == 50000000) {
            return BuildingType.Cart;
        }
    }

    function _getProfitForType(BuildingType type) internal {

    }

    function _getConditionModifier(BuildingCondition mod) internal {
        if (mod == BuildingCondition.Pristine) {
            return 100;
        } else if (mod == BuildingCondition.VeryGood) {
            return 90;
        } else if (mod == BuildingCondition.Good) {
            return 75;
        } else if (mod == BuildingCondition.Fair) {
            return 50;
        } else if (mod == BuildingCondition.Poor) {
            return 25;
        } else if (mod == BuildingCondition.Derelict) {
            return 10;
        }
    }
}
