//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from 'forge-std/Test.sol';   
import {DeployTokenDivider} from 'script/DeployTokenDivider.s.sol';
import {TokenDivider} from 'src/TokenDivider.sol';
import {ERC721Mock} from '../mocks/ERC721Mock.sol';
import {ERC20Mock} from '@openzeppelin/contracts/mocks/token/ERC20Mock.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

contract ERC20TransferOutsideOfContractTest is Test {
    DeployTokenDivider deployer;
    TokenDivider tokenDivider;
    ERC721Mock erc721Mock;

    address public INITIALHOLDER = makeAddr("initialNftHolder");
    address public FRIEND = makeAddr("friendOfInitialNftHolder");

    uint256 constant public STARTING_USER_BALANCE = 10e18;  // 10 eth
    uint256 constant public AMOUNT = 2e18; // 2e18 tokens
    uint256 constant public TOKEN_ID = 0;

    function setUp() public {
        deployer = new DeployTokenDivider();
        tokenDivider = deployer.run();
        
        erc721Mock = new ERC721Mock();
        
        erc721Mock.mint(INITIALHOLDER);
        vm.deal(INITIALHOLDER, STARTING_USER_BALANCE);
        vm.deal(FRIEND, STARTING_USER_BALANCE);
    }

    function testTransferFromInitialHolderToFriendOutsideOfContract() public {

        vm.startPrank(INITIALHOLDER);   // impersonate the initial holder of the NFT
        erc721Mock.approve(address(tokenDivider), TOKEN_ID);    // approve the token divider to spend the NFT

        tokenDivider.divideNft(address(erc721Mock), TOKEN_ID, AMOUNT);  // divide the NFT
        

        // transfer the erc20 token from the initial holder to the friend outside of the contract
        ERC20Mock erc20Mock = ERC20Mock(tokenDivider.getErc20InfoFromNft(address(erc721Mock)).erc20Address);
        console.log("Balance of friend outside of the contract: ", erc20Mock.balanceOf(FRIEND));
        console.log("Balance of initial holder within the contract: ", tokenDivider.getBalanceOf(INITIALHOLDER,  address(erc20Mock)));
        console.log("transfering the tokens from the initial holder to the friend outside of the contract");
        erc20Mock.transfer(FRIEND, AMOUNT);
        console.log("Balance of friend outside of the contract: ", erc20Mock.balanceOf(FRIEND));
        console.log("Balance of friend within the contract: ", tokenDivider.getBalanceOf(FRIEND,  address(erc20Mock)));
        console.log("Balance of initial holder outside of the contract: ", erc20Mock.balanceOf(INITIALHOLDER));
        console.log("Balance of initial holder within the contract: ", tokenDivider.getBalanceOf(INITIALHOLDER,  address(erc20Mock)));
        //accounting is off.

        //if we try to create sell order from initial holder, it not work, but they will not have the tokens
        //if we try to create sell order from friend, it will not work, but they do have the tokens
        // tokenDivider.sellErc20(address(erc20Mock),1e18, AMOUNT);
        // console.log("order created by initial holder");
        // vm.stopPrank();
        console.log('friend is creating a sell order');
        vm.startPrank(FRIEND);
        tokenDivider.sellErc20(address(erc20Mock), 1e18, AMOUNT-2);
        console.log("order created by friend");
        vm.stopPrank();
        

        // check the balance of the initial holder within the contract

    }


}