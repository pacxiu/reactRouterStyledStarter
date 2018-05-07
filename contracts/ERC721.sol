pragma solidity ^0.4.22;

// @title Interface for contracts conforming to ERC-721: Non-Fungible Tokens
// @author Dieter Shirley <dete@axiomzen.co> (https://github.com/dete)
contract ERC721 {
  	// Required methods
  	function approve(address _to, uint256 _tokenId) public;
  	function balanceOf(address _owner) public view returns (uint256 balance);
  	function implementsERC721() public pure returns (bool);
  	function ownerOf(uint256 _tokenId) public view returns (address addr);
  	function takeOwnership(uint256 _tokenId) public;
  	function totalSupply() public view returns (uint256 total);
  	function transferFrom(address _from, address _to, uint256 _tokenId) public;
  	function transfer(address _to, uint256 _tokenId) public;
	
  	event Transfer(address indexed from, address indexed to, uint256 tokenId);
  	event Approval(address indexed owner, address indexed approved, uint256 tokenId);
}