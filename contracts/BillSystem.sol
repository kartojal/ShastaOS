pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "zos-lib/contracts/migrations/Migratable.sol";


/**
 * @title BillSystem
 */

contract BillSystem is Ownable, Migratable {
  address public ledgerAddress;
  

  struct Bill {
    uint256 whConsumed;
    address tokenAddress; // If tokenAddress 0x00 == ETHER as payment
    address seller;
    address consumer;
    uint256 price;
    uint256 amount;
    string ipfsMetadata;
  }

  Bill[] public bills;
  
  mapping(address => uint256[]) sellerBillIndex;
  mapping(address => uint256[]) consumerBillIndex;
  mapping(address => string) consumerMetadataIpfs;
  mapping(uint => bool) isBillPaid;
  // mapping of token addresses to mapping of account balances (token=0 means Ether)
  mapping (address => mapping (address => uint)) public balances; 

  event NewBill(address consumer, address seller, uint index);
  event Newseller(address seller);

  // Upgradeable contract pattern with initializer using zeppelinOS way.
  function initialize() public isInitializer("ShastaBillSystem", "0") {
  }

  function getBill(uint index) public view returns(
    uint256 whConsumed,
    address tokenAddress,
    address seller,
    address consumer,
    uint256 price,
    uint256 amount,
    string ipfsMetadata
  ) {
    Bill memory bill = bills[index];

    whConsumed = bill.whConsumed;
    tokenAddress = bill.tokenAddress;
    seller = bill.seller;
    consumer = bill.consumer;
    price = bill.price;
    amount = bill.amount;
    ipfsMetadata = bill.ipfsMetadata;
  }

  function getBillsLength() public view returns (uint length) {
    length = bills.length;
  }

  function getBalance(address tokenAddress, address userAddress) public view returns(uint256 balance) {
    balance = balances[tokenAddress][userAddress];
  }

  function generateBill(uint wh, uint price, address seller, address tokenAddress, string ipfsMetadata) public returns (bool) {
    uint newIndex = bills.push(Bill(wh, tokenAddress, seller, msg.sender, price, wh * price, ipfsMetadata));
    consumerBillIndex[msg.sender].push(newIndex);
    sellerBillIndex[msg.sender].push(newIndex);
    emit NewBill(msg.sender, seller, newIndex);
  }

  function payBillERC20(address tokenAddress, address consumer, uint256 amount, uint256 billIndex) public {
    IERC20 tokenInstance = IERC20(tokenAddress);
    Bill memory bill = bills[billIndex];
    require(bill.tokenAddress == tokenAddress, "The ERC20 token is not the same as defined in the contract.");
    require(bill.consumer == consumer, "Bill is from consumer");
    require(bill.amount > 0, "Bill does not exists");
    require(bill.amount == amount, "Bill amount is not the same as the amount argument.");
    require(isBillPaid[billIndex] == false, "Bill is already paid.");
    // Add allowance requirement, for better error handling HERE
    tokenInstance.transferFrom(consumer, address(this), amount);
    isBillPaid[billIndex] = true;
    balances[tokenAddress][bill.seller] += amount;
  }

  function payBillETH(uint256 billIndex) public payable {
    Bill memory bill = bills[billIndex];
    require(bill.tokenAddress == address(0), "The ERC20 token is not the same as defined in the contract.");
    require(bill.consumer == msg.sender, "Bill is from consumer");
    require(bill.amount > 0, "Bill does not exists");
    require(bill.amount == msg.value, "Bill amount is not the same as the amount argument.");
    require(isBillPaid[billIndex] == false, "Bill is already paid.");
    isBillPaid[billIndex] = true;
    balances[address(0)][bill.seller] += msg.value;
  }

  function withdrawETH() public {
    uint256 allBalance = balances[address(0)][msg.sender];
    require(allBalance > 0,  "No balance left.");
    balances[address(0)][msg.sender] = 0;
    msg.sender.transfer(allBalance);
  }

  function withdrawERC20(address tokenAddress) public {
    require(tokenAddress != address(0), "Token address can not be zero. Reserved for ETH payments.");
    uint256 allBalance = balances[tokenAddress][msg.sender];
    require(allBalance > 0,  "No balance left.");
    balances[tokenAddress][msg.sender] = 0;
    require(IERC20(tokenAddress).transfer(msg.sender, allBalance), "Error while making ERC20 transfer");
  }
}