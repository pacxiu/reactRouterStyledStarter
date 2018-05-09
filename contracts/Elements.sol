pragma solidity ^0.4.22;

import './ERC721.sol';
import './Pausable.sol';
import './SafeMath.sol';

contract Heroes is ERC721, Pausable {
	using SafeMath for uint256;

  	/*** EVENTS ***/
  	// @dev The Birth event is fired whenever a new hero comes into existence.
  	event Birth(uint256 tokenId, string name, address owner);

  	// @dev The TokenSold event is fired whenever a token is sold.
  	event TokenSold(uint256 tokenId, uint256 oldPrice, uint256 newPrice, address prevOwner, string name);

  	// @dev Transfer event as defined in current draft of ERC721. Ownership is assigned, including births.
  	event Transfer(address from, address to, uint256 tokenId);

  	/*** STORAGE ***/

  	// @dev A mapping from hero IDs to the address that owns them. All heroes have
  	//  some valid owner address.
  	mapping (uint256 => address) public heroIndexToOwner;

  	// @dev A mapping from owner address to count of tokens that address owns.
  	//  Used internally inside balanceOf() to resolve ownership count.
  	mapping (address => uint256) private ownershipTokenCount;

  	// @dev A mapping from HeroIDs to an address that has been approved to call
  	//  transferFrom(). Each Hero can only have one approved address for transfer
  	//  at any time. A zero value means no approval is outstanding.
  	mapping (uint256 => address) public heroIndexToApproved;

  	// @dev A mapping from HeroIDs to the price of the token.
  	mapping (uint256 => uint256) private heroIndexToPrice;

  	// @dev A mapping to check if Boss was attacked
  	mapping (uint256 => mapping (uint256 => bool) ) private bossDefeated;

  	/*** CONSTANTS, VARIABLES ***/
	// @notice Name and symbol of the non fungible token, as defined in ERC721.
	string public constant NAME = "EtherComics"; // solhint-disable-line
	string public constant SYMBOL = "ECO"; // solhint-disable-line

	uint256 private premiumPrice = 0.2 ether;
  	uint256 private startingPrice = 0.05 ether;
  	uint256 private levelPrice = 0.05 ether;
  	uint256 private statPrice = 0.001 ether;

  	uint256 private bossPool = 0;
  	bool public hotPotatoPhase;

  	uint256 hotPotatoCooldown = 2 hours;
  	uint256 hotPotatoTimer;

  	/*** DATATYPES ***/
  	struct Hero {
  		uint256 tokenId;
    	string name;
    	uint256 level;
    	uint256 heroAttack;
    	uint256 heroDefense;
    	uint256 bounty;
  	}

  	struct Boss {
  		uint256 tokenId;
    	string name;
    	uint256 bossAttack;
    	uint256 bossDefense;
  	}

  	mapping(uint256 => Hero) heroes;
  	mapping(uint256 => Boss) bosses;

  	uint256[] tokens;
  	uint256[] gameBosses;

  	/*** CONSTRUCTOR ***/
  	constructor() public {
  		pause();
  		startHotPotato();
  	}

  	/*** PUBLIC FUNCTIONS ***/
  	// @notice Grant another address the right to transfer token via takeOwnership() and transferFrom().
  	// @param _to The address to be granted transfer approval. Pass address(0) to
  	//  clear all approvals.
  	// @param _tokenId The ID of the Token that can be transferred if this call succeeds.
  	// @dev Required for ERC-721 compliance.
  	function approve(address _to, uint256 _tokenId) public {
  	  	// Caller must own token.
  	  	require(_owns(msg.sender, _tokenId));
	
	  	heroIndexToApproved[_tokenId] = _to;
	
	  	emit Approval(msg.sender, _to, _tokenId);
  	}

  	// For querying balance of a particular account
  	// @param _owner The address for balance query
  	// @dev Required for ERC-721 compliance.
  	function balanceOf(address _owner) public view returns (uint256 balance) {
    	return ownershipTokenCount[_owner];
  	}

  	function implementsERC721() public pure returns (bool) {
    	return true;
  	}

  	// For querying owner of token
  	// @param _tokenId The tokenID for owner inquiry
  	// @dev Required for ERC-721 compliance.
  	function ownerOf(uint256 _tokenId) public view returns (address owner) {
    	owner = heroIndexToOwner[_tokenId];
    	require(owner != address(0));
  	}

  	// Allows someone to send ether and obtain the token
  	function purchase(uint256 _tokenId) public payable hotPotato {
    	address oldOwner = heroIndexToOwner[_tokenId];
    	address newOwner = msg.sender;

    	uint256 sellingPrice = heroIndexToPrice[_tokenId];
    	// Making sure token owner is not sending to self
    	require(oldOwner != newOwner);
    	require(sellingPrice > 0);

    	// Safety check to prevent against an unexpected 0x0 default.
    	require(_addressNotNull(newOwner));

    	// Making sure sent amount is greater than or equal to the sellingPrice
    	require(msg.value >= sellingPrice);

    	uint256 ownerPayout = SafeMath.mul(SafeMath.div(sellingPrice, 100), 91);
    	uint256 purchaseExcess = SafeMath.sub(msg.value, sellingPrice);

    	// fee = 3% ( (100 - 91) / 3 )
    	uint256	fee = SafeMath.div(SafeMath.sub(sellingPrice, ownerPayout), 3);

    	// Pay previous tokenOwner if owner is not contract
    	// and if previous price is not 0
    	if (oldOwner != address(this)) {
      		// old owner gets entire initial payment back
      		oldOwner.transfer(ownerPayout);
    	} else {
      		fee = SafeMath.add(fee, ownerPayout);
    	}
	        
    	if (purchaseExcess > 0) {
    		msg.sender.transfer(purchaseExcess);
    	}

    	// transfer fee, and add to bounties
    	owner.transfer(fee);
		bossPool = bossPool.add(fee);
		heroes[_tokenId].bounty = heroes[_tokenId].bounty.add(fee);

    	_transfer(oldOwner, newOwner, _tokenId);

    	//TokenSold(_tokenId, sellingPrice, heroIndexToPrice[_tokenId], oldOwner, newOwner, heroes[_tokenId].name);

    	// Update price
      	heroIndexToPrice[_tokenId] = SafeMath.div(SafeMath.mul(sellingPrice, 117), 100);
  	}

  	function priceOf(uint256 _tokenId) public view returns (uint256 price) {
	    return heroIndexToPrice[_tokenId];
  	}

  	// @notice Allow pre-approved user to take ownership of a token
  	// @param _tokenId The ID of the Token that can be transferred if this call succeeds.
  	// @dev Required for ERC-721 compliance.
  	function takeOwnership(uint256 _tokenId) public {
    	address newOwner = msg.sender;
    	address oldOwner = heroIndexToOwner[_tokenId];

    	// Safety check to prevent against an unexpected 0x0 default.
    	require(_addressNotNull(newOwner));

    	// Making sure transfer is approved
    	require(_approved(newOwner, _tokenId));

    	_transfer(oldOwner, newOwner, _tokenId);
  	}

  	// @param _owner The owner whose hero tokens we are interested in.
  	// @dev This method MUST NEVER be called by smart contract code. First, it's fairly
  	//  expensive (it walks the entire Heroes array looking for heroes belonging to owner),
  	//  but it also returns a dynamic array, which is only supported for web3 calls, and
  	//  not contract-to-contract calls.
  	function tokensOfOwner(address _owner) public view returns(uint256[] ownerTokens) {
    	uint256 tokenCount = balanceOf(_owner);
    	if (tokenCount == 0) {
        	// Return an empty array
      		return new uint256[](0);
    	} else {
      		uint256[] memory result = new uint256[](tokenCount);
      		uint256 totalHeroes = totalSupply();
      		uint256 resultIndex = 0;
      		uint256 heroId;
      		for (heroId = 0; heroId < totalHeroes; heroId++) {
      			uint256 tokenId = tokens[heroId];

		        if (heroIndexToOwner[tokenId] == _owner) {
		          result[resultIndex] = tokenId;
		          resultIndex++;
		        }
      		}
      		return result;
    	}
  	}

  	// For querying totalSupply of token
  	// @dev Required for ERC-721 compliance.
  	function totalSupply() public view returns (uint256 total) {
    	return tokens.length;
  	}

  	// Owner initates the transfer of the token to another account
  	// @param _to The address for the token to be transferred to.
  	// @param _tokenId The ID of the Token that can be transferred if this call succeeds.
  	// @dev Required for ERC-721 compliance.
  	function transfer( address _to, uint256 _tokenId ) public {
   		require(_owns(msg.sender, _tokenId));
    	require(_addressNotNull(_to));
    	_transfer(msg.sender, _to, _tokenId);
  	}

  	// Third-party initiates transfer of token from address _from to address _to
  	// @param _from The address for the token to be transferred from.
  	// @param _to The address for the token to be transferred to.
  	// @param _tokenId The ID of the Token that can be transferred if this call succeeds.
  	// @dev Required for ERC-721 compliance.
  	function transferFrom( address _from, address _to, uint256 _tokenId) public {
    	require(_owns(_from, _tokenId));
    	require(_approved(_to, _tokenId));
    	require(_addressNotNull(_to));
    	_transfer(_from, _to, _tokenId);
  	}

  	/*** PRIVATE FUNCTIONS ***/
  	// Safety check on _to address to prevent against an unexpected 0x0 default.
  	function _addressNotNull(address _to) private pure returns (bool) {
    	return _to != address(0);
  	}

  	// For checking approval of transfer for address _to
	function _approved(address _to, uint256 _tokenId) private view returns (bool) {
		return heroIndexToApproved[_tokenId] == _to;
	}

  	// Check for token ownership
  	function _owns(address claimant, uint256 _tokenId) private view returns (bool) {
    	return claimant == heroIndexToOwner[_tokenId];
  	}

  	// @dev Assigns ownership of a specific Hero to an address.
  	function _transfer(address _from, address _to, uint256 _tokenId) private {
  	  	// Since the number of heroes is capped to 2^32 we can't overflow this
  	  	ownershipTokenCount[_to]++;
  	  	//transfer ownership
  	  	heroIndexToOwner[_tokenId] = _to;
  	  	// When creating new heroes _from is 0x0, but we can't account that address.
  	  	if (_from != address(0)) {
  	    	ownershipTokenCount[_from]--;
  	    	// clear any previously approved ownership exchange
  	    	delete heroIndexToApproved[_tokenId];
  	  	}
  	  	// Emit the transfer event.
  	  	emit Transfer(_from, _to, _tokenId);
  	}


  	//*** CUSTOM FUNCTIONS ***

  	// @notice Returns all the relevant information about a specific hero.
  	// @param _tokenId The tokenId of the hero of interest.
  	function getHero(uint256 _tokenId) public view returns (
  		uint256 tokenId,
    	string heroName,
    	uint256 level,
    	uint256 heroAttack,
    	uint256 heroDefense,
    	uint256 bounty,
    	uint256 sellingPrice,
    	address owner
  	) {
    	Hero storage hero = heroes[_tokenId];
    	tokenId = hero.tokenId;
    	heroName = hero.name;
    	level = hero.level;
    	heroAttack = hero.heroAttack;
    	heroDefense = hero.heroDefense;
    	bounty = hero.bounty;
    	sellingPrice = heroIndexToPrice[_tokenId];
    	owner = heroIndexToOwner[_tokenId];
  	}

  	function getBoss(uint256 _tokenId) public view returns (
  		uint256 tokenId,
    	string bossName,
    	uint256 bossAttack,
    	uint256 bossDefense
  	) {
    	Boss storage boss = bosses[_tokenId];
    	tokenId = boss.tokenId;
    	bossName = boss.name;
    	bossAttack = boss.bossAttack;
    	bossDefense = boss.bossDefense;
  	}

	// Private method for creating Hero
  	function _createHero(string _name, address _owner, uint256 _price, uint256 _level, uint256 _heroAttack, uint256 _heroDefense) private returns (string) {
    	uint256 newHeroId = tokens.length;
    	// It's probably never going to happen, 4 billion tokens are A LOT, but
    	// let's just be 100% sure we never let this happen.
    	require(newHeroId == uint256(uint32(newHeroId)));

    	heroes[newHeroId] = Hero(newHeroId, _name, _level, _heroAttack, _heroDefense, 0);

    	emit Birth(newHeroId, _name, _owner);

    	heroIndexToPrice[newHeroId] = _price;

    	// This will assign ownership, and also emit the Transfer event as
    	// per ERC721 draft
    	_transfer(address(0), _owner, newHeroId);

    	tokens.push(newHeroId);

    	return _name;
  	}

  	// @dev Creates a new Hero
  	function createHero(string _name) public onlyOwner whenNotPaused {
    	_createHero(_name, address(this), startingPrice, 1, 0, 0);
  	}

  	// @dev Creates a new Premium Hero
  	function createPremiumHero(string _name, uint256 _level, uint256 _heroAttack, uint256 _heroDefense) public onlyOwner whenNotPaused {
    	_createHero(_name, address(this), premiumPrice, _level, _heroAttack, _heroDefense);
  	}

  	// Private method for creating Boss
  	function _createBoss(string _name, uint256 _bossAttack, uint256 _bossDefense) private returns (string) {
    	uint256 newBossId = gameBosses.length;
    	// It's probably never going to happen, 4 billion tokens are A LOT, but
    	// let's just be 100% sure we never let this happen.
    	require(newBossId == uint256(uint32(newBossId)));

    	bosses[newBossId] = Boss(newBossId, _name, _bossAttack, _bossDefense);

    	gameBosses.push(newBossId);

    	return _name;
  	}

  	// @dev Creates a new Boss
  	function createBoss(string _name, uint256 _bossAttack, uint256 _bossDefense) public onlyOwner whenNotPaused {
    	_createBoss(_name, _bossAttack, _bossDefense);
  	}

  	// This function can be used by the owner of a token to modify the current price
	function modifyTokenPrice(uint256 _tokenId, uint256 _newPrice) external payable onlyHeroOwner(_tokenId) whenNotPaused {
	    require(_newPrice > startingPrice);
	    require(_newPrice < heroIndexToPrice[_tokenId]);

	    heroIndexToPrice[_tokenId] = _newPrice;
	}

	// leveling up characters
	function levelUp(uint256 _tokenId) external payable onlyHeroOwner(_tokenId) whenNotPaused {
		require(msg.value == levelPrice);
		Hero storage hero = heroes[_tokenId];

		hero.level = hero.level.add(1);

		// bounties, fees
		uint256 fee = SafeMath.div(SafeMath.mul(msg.value, 100), 20);
		uint256 bossBounty = SafeMath.div(SafeMath.mul(msg.value, 100), 30);
		uint256 heroBounty = SafeMath.div(SafeMath.mul(msg.value, 100), 50);

		owner.transfer(fee);
		bossPool = bossPool.add(bossBounty);
		hero.bounty = hero.bounty.add(heroBounty);
	}

	// upgradeStats for hero
	function upgradeStats(uint256 _tokenId, uint256 statPoints, bool attackStat) external payable onlyHeroOwner(_tokenId) whenNotPaused {
		uint256 totalPrice = statPoints.mul(statPrice);
		require(msg.value == totalPrice);

		Hero storage hero = heroes[_tokenId];

		if (attackStat) {
			hero.heroAttack = hero.heroAttack.add(statPoints);
		} else {
			hero.heroDefense = hero.heroDefense.add(statPoints);
		}

		// bounties, fees
		uint256 fee = SafeMath.div(SafeMath.mul(msg.value, 100), 20);
		uint256 bossBounty = SafeMath.div(SafeMath.mul(msg.value, 100), 30);
		uint256 heroBounty = SafeMath.div(SafeMath.mul(msg.value, 100), 50);

		owner.transfer(fee);
		bossPool = bossPool.add(bossBounty);
		hero.bounty = hero.bounty.add(heroBounty);
	}

	function attackBoss(uint256 _heroId, uint256 _bossId) external onlyHeroOwner(_heroId) whenNotPaused notHotPotato {
		// can only defeat once
		require(!bossDefeated[_heroId][_bossId]);
		require( heroes[_heroId].heroAttack > bosses[_bossId].bossDefense );

		// transfer 3% from bossPool
		uint256 reward = SafeMath.div(SafeMath.mul(bossPool, 100), 3);
		heroIndexToOwner[_heroId].transfer(reward);

		bossPool = bossPool.sub(reward);
		bossDefeated[_heroId][_bossId] = true;
	}

	function attackPlayer(uint256 _heroId, uint256 _targetHeroId) external onlyHeroOwner(_heroId) whenNotPaused notHotPotato {
		// can't attack your own heroes
		require( heroIndexToOwner[_heroId] != heroIndexToOwner[_targetHeroId]);

		Hero storage heroAttacker = heroes[_heroId];
        Hero storage heroDefender = heroes[_targetHeroId];

		require( heroAttacker.heroAttack > heroDefender.heroDefense );

		// transfer 25% from bounty
		uint256 reward = SafeMath.div(SafeMath.mul(heroDefender.bounty, 100), 25);
		heroIndexToOwner[_heroId].transfer(reward);
		heroDefender.bounty = heroDefender.bounty.sub(reward);
	}

	//*** CUSTOM EVENTS ***
	event StartHotPotato();
  	event StopHotPotato();


  	//*** CUSTOM MODIFIERS ***
  	// @dev actions specified only for hero owner
  	modifier onlyHeroOwner(uint256 _tokenId) {
  		require(heroIndexToOwner[_tokenId] == msg.sender);
    	_;
  	}

  	modifier hotPotato() {
  		require(hotPotatoPhase);
  		_;
  	}

  	modifier notHotPotato() {
  		require(!hotPotatoPhase);
  		_;
  	}

  	function startHotPotato() onlyOwner public {
	    hotPotatoPhase = true;
	    hotPotatoTimer = now;

	    emit StartHotPotato();
	}

	function stopHotPotato() public {
		require(now >= hotPotatoTimer + hotPotatoCooldown);

	    hotPotatoPhase = false;
	    emit StopHotPotato();
	}
}