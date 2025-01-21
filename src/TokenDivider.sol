// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20ToGenerateNftFraccion} from "src/token/ERC20ToGenerateNftFraccion.sol";
import {IERC721, ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenDivider
 * @author Juan Pedro Ventura Baltian, 14 years old
 * @notice This contracts was created, with the intention to make a new market of nft franctions 
 * There are a function to divide an nft, then you can sell and buy some fraction of nft, that are basicaly 
 * erc20 tokens, each nft pegged to an nft.There are some validations, to make the platforme the most secure 
 * as possible.This is the first project that i code alone, in blockchain, foundry and solidity. 
 * Thank you so much for read it.
 */
 

contract  TokenDivider is IERC721Receiver,Ownable   {

    error TokenDivider__NotFromNftOwner();
    error  TokenDivider__NotEnoughErc20Balance();
    error TokenDivider__NftTransferFailed();
    error TokenDivider__InsuficientBalance();
    error TokenDivider__CantTransferToAddressZero();
    error TokenDivider__TransferFailed();
    error TokenDivider__NftAddressIsZero();
    error TokenDivider__AmountCantBeZero();
    error TokenDivider__InvalidSeller();
    error TokenDivier__InvalidAmount();
    error TokenDivider__IncorrectEtherAmount();
    error TokenDivider__InsuficientEtherForFees();

    struct ERC20Info {
        address erc20Address;
        uint256 tokenId;
    }

    struct SellOrder {
        address seller;
        address erc20Address;
        uint256 price;
        uint256 amount;
    }


    /**
     * @dev balances Relates a user with an amount of a erc20 token, this erc20 tokens is an nft fraction
     
     @dev nftToErc20Info Relates an nft with the erc20 pegged, and othe data like the erc20 amount, or the tokenId
     
     @dev s_userToSellOrders Relates a user with an array of sell orders, that each sell order 
     has a seller, an erc20 that is the token to sell, a price and an amount of erc20 to sell
     
     */
    mapping(address user => mapping(address erc20Address => uint256 amount)) balances; 
    mapping(address nft => ERC20Info) nftToErc20Info;
    mapping(address user => SellOrder[] orders) s_userToSellOrders;
    mapping(address erc20 =>  address nft) erc20ToNft;
    mapping(address erc20 => uint256 totalErc20Minted) erc20ToMintedAmount;

    event NftDivided(address indexed nftAddress, uint256 indexed amountErc20Minted, address indexed erc20Minted);
    event NftClaimed(address indexed nftAddress);
    event TokensTransfered(uint256 indexed amount, address indexed erc20Address);
    event OrderPublished(uint256 indexed amount, address indexed seller, address indexed nftPegged);
    event OrderSelled(address indexed buyer, uint256 price);


    /**
     * 
     *  Only the owner of the nft can call a function with this modifier
     */
    modifier onlyNftOwner(address nft, uint256 tokenId) {
        if(msg.sender != IERC721(nft).ownerOf(tokenId)) {
            revert TokenDivider__NotFromNftOwner();
        }
        _;
    }

    constructor() Ownable(msg.sender) {}



    /**
     * @dev Handles the receipt of an ERC721 token. This function is called whenever an ERC721 token is transferred to this contract.
     */
    function onERC721Received(
        address /* operator */,
        address /* from */,
        uint256 /*  tokenId */,
        bytes calldata /* data */
    ) external pure override returns (bytes4) {
        // Return this value to confirm the receipt of the NFT
        return this.onERC721Received.selector;
    }

    /**
     * 
     * @param nftAddress The addres of the nft to divide
     * @param tokenId The id of the token to divide
     * @param amount The amount of erc20 tokens to mint for the nft
     * 
     * @dev in this function, the nft passed as parameter, is locked by transfering it to this contract, then, it gives to the 
     * person calling this function an amount of erc20, beeing like a fraction of this nft.
     */

    // @audit This function has 2 of the same modifiers, it should be only one
    function divideNft(address nftAddress, uint256 tokenId, uint256 amount) onlyNftOwner(nftAddress, tokenId) onlyNftOwner(nftAddress ,tokenId) external {
        
        //check if nft is valid (non zero address)
        if(nftAddress == address(0)) { revert TokenDivider__NftAddressIsZero(); }
        //check if amount is valid (non zero)
        if(amount == 0) { revert TokenDivider__AmountCantBeZero(); }

        //create a new erc20 contract tokens that correlates to the specific tokenid of an erc721 token
        ERC20ToGenerateNftFraccion erc20Contract = new ERC20ToGenerateNftFraccion(
            string(abi.encodePacked(ERC721(nftAddress).name(), "Fraccion")), 
            string(abi.encodePacked("F", ERC721(nftAddress).symbol())));

        //mint the amount of erc20 tokens to the contract
        erc20Contract.mint(address(this), amount);
        //get the address of the erc20 contract created
        address erc20 = address(erc20Contract);

        //transfer the nft to the contract MSG.SENDER NFTCOUNT: 0, CONTRACT NFTCOUNT: 1
        IERC721(nftAddress).safeTransferFrom(msg.sender, address(this), tokenId, "");

        //check if the nft is still held by the msg.sender, shouldnt, if it is, revert
        if(IERC721(nftAddress).ownerOf(tokenId) == msg.sender) { revert TokenDivider__NftTransferFailed(); }

        //set the balances of the msg.sender to the amount of erc20 tokens minted, tokens are still all in this contract, but the mapping suggests that the msg.sender holds them
        balances[msg.sender][erc20] = amount;

        //set the nft to erc20 info, with the erc20 address and the tokenid, 
        //would be better if this is set during the minting of the token at the ERC20ToGenerateNftFraccion step
        nftToErc20Info[nftAddress] = ERC20Info({erc20Address: erc20, tokenId: tokenId});

        //set the total amount of erc20 minted for this nft
        erc20ToMintedAmount[erc20] = amount;
        //set the nft to erc20 mapping
        erc20ToNft[erc20] = nftAddress;

        emit NftDivided(nftAddress, amount, erc20);
        
        //send the erc20 tokens to the msg.sender, contract holds NFTCOUNT: 1, ERC20: 0, msg.sender holds NFTCOUNT: 0, ERC20: AMOUNT
        bool transferSuccess = IERC20(erc20).transfer(msg.sender, amount);
        if(!transferSuccess) {
            revert TokenDivider__TransferFailed();
        }
    }

    /**
     * 
     * @param nftAddress  The address of the nft to claim
     * 
     * @dev in this function, if you have all the erc20 minted for the nft, you can call this function to claim the nft, 
     * giving to the contract all the erc20 and it will give you back the nft
     */

    //@audit make sure (c->e->i) is followed (c):check , (e):effects, (i):interactions
    function claimNft(address nftAddress) external {

        //(c) check if the nft address is valid
        if(nftAddress == address(0)) {
            revert TokenDivider__NftAddressIsZero();
        }

        //get the erc20 info of the nft and store it in a memory variable
        ERC20Info storage tokenInfo = nftToErc20Info[nftAddress];
        
        //(c) check if the msg.sender balances are enough to execute the claim
        //balances[msg.sender][tokenInfo.erc20Address] is the amount of erc20 tokens the msg.sender holds
        //erc20ToMintedAmount[tokenInfo.erc20Address] is the total amount of erc20 tokens minted for this nft
        //this means if the msg.sender holds all the erc20 tokens minted for this nft, they can claim the nft
        if(balances[msg.sender][tokenInfo.erc20Address] < erc20ToMintedAmount[tokenInfo.erc20Address]) {
            revert TokenDivider__NotEnoughErc20Balance();
        }

        //@audit (!!!) his interaction appears before the state changes, it should be after, might have reentracy issues, burnFrom looks safe though.

        //(i) interaction: burn the erc20 tokens from the msg.sender
        ERC20ToGenerateNftFraccion(tokenInfo.erc20Address).burnFrom(msg.sender, erc20ToMintedAmount[tokenInfo.erc20Address]);

        //(e) statechanged: set the balances of the msg.sender to 0
        balances[msg.sender][tokenInfo.erc20Address] = 0;
        //(e): statechanged: set the total amount of erc20 minted for this nft to 0
        erc20ToMintedAmount[tokenInfo.erc20Address] = 0;

        emit NftClaimed(nftAddress);

        //(i) interaction: transfer the nft to the msg.sender
        IERC721(nftAddress).safeTransferFrom(address(this), msg.sender, tokenInfo.tokenId);
    }




    /**
     * 
     * @param nftAddress The nft address pegged to the erc20
     * @param to The reciver of the erc20
     * @param amount The amount of erc20 to transfer
     * 
     * @dev you can use this function to transfer nft franctions 100% securily and registered by te contract
     */

     //@audit alot of accounting here, make sure there are no inconsistencies

    function transferErcTokens(address nftAddress,address to, uint256 amount) external {
        
        //check if the nft address is valid(non zero)
        if(nftAddress == address(0)) {
            revert TokenDivider__NftAddressIsZero();
        }

        //check if transferring to address 0, (!!!) doesnt work or stops user from doing so, user could still approve and send the tokens to address 0 through the erc20 contract, balances tracked will be off
        if(to == address(0)) {
            revert TokenDivider__CantTransferToAddressZero();
        }

        // if the amount sent is 0, revert
        if(amount == 0) {
            revert TokenDivider__AmountCantBeZero();
        }

        //get the erc20 info of the nft and store it in a memory variable
        ERC20Info memory tokenInfo = nftToErc20Info[nftAddress];

        //repeated check if it is transfering to address 0, still, doesnt work
        if(to == address(0)) {
            revert TokenDivider__CantTransferToAddressZero();
        }

        //check if the msg.sender has enough erc20 tokens to transfer,
        //someone might have transferred the erc20 tokens to the msg.sender, 
        //but the mapping in the contract hasnt been updated. 
        //the contract thinks the msg.sender doesn't have the erc20 tokens, but they actually do
        //(!!!) this is a DOS vector.
        if(balances[msg.sender][tokenInfo.erc20Address] < amount) {
            revert TokenDivider__NotEnoughErc20Balance();
        }

        //state change: subtract the amount of erc20 tokens from the msg.sender
        balances[msg.sender][tokenInfo.erc20Address] -= amount;
        //state change: add the amount of erc20 tokens to the reciever
        balances[to][tokenInfo.erc20Address] += amount;

        emit TokensTransfered(amount, tokenInfo.erc20Address);

        //interact: transfer the erc20 tokens from the msg.sender to the reciever, 
        // this might fail... 
        // because msg.sender might not have the erc20 tokens, 
        // but the contract thinks they do
        // this is a DOS vector
        IERC20(tokenInfo.erc20Address).transferFrom(msg.sender,to, amount);
    }

    /**
     * 
     * @param nftPegged The nft address pegged to the tokens to sell
     * @param price The price of all the tokens to sell
     * @param amount  The amount of tokens to sell
     * 
     * @dev this function creates a new order, is like publish you assets into a marketplace, where other persons can buy it.
     * firstly, once you call this function, the amount of tokens that you passed into as a parameter, get blocked,  by sending it 
     * to this contract, then a new order is created and published.
     */

    
    function sellErc20(address nftPegged, uint256 price,uint256 amount) external {
        //cant set nft to zero address
        if(nftPegged == address(0)) {
            revert TokenDivider__NftAddressIsZero();
        }
        //cant set amount to sell to zero
        if( amount == 0) {
            revert TokenDivider__AmountCantBeZero();
        }
        
        ERC20Info memory tokenInfo = nftToErc20Info[nftPegged]; 
        //balances[msg.sender][tokenInfo.erc20Address] is the amount of erc20 tokens the msg.sender holds
        //someone might have transferred the tokens in to the address, but the contract state hasnt been updated
        //(!!!) this is a DOS vector, where the contract thinks the msg.sender doesnt have the erc20 tokens, but they actually do
        if(balances[msg.sender][tokenInfo.erc20Address] < amount) {
            revert TokenDivider__InsuficientBalance();
        }

        //state change: subtract the amount of erc20 tokens from the msg.sender
        balances[msg.sender][tokenInfo.erc20Address] -= amount;

        //state change: add the order to the user's orders
        s_userToSellOrders[msg.sender].push(
             SellOrder({
                seller: msg.sender,
                erc20Address: tokenInfo.erc20Address,
                price: price,
                amount: amount
            })
        );

        emit OrderPublished(amount,msg.sender, nftPegged);

        //interact: transfer the erc20 tokens to the contract, so it can be sold
        //if user doesnt have the erc20 tokens, the contract will think they do, and the transfer will fail
        //users who dont have the tokens but contract think they do have are users who have 
        //transferred the tokens to another address but accounting here isnt updated.
        //this is a DOS vector, because transferFrom will revert.
        IERC20(tokenInfo.erc20Address).transferFrom(msg.sender,address(this), amount);
    }
    

    /**
     * 
     * @param orderIndex The index of the order in all the orders array of the seller (the seller can have multiple orders active)
     * @param seller The person who is selling this tokens
     * 
     * @dev when the buyer call this function, the eth or any token accepted to pay, is sent to the seller
     * if the transfer executed correctly, then this contract, wich has all the tokens, send the tokens to the msg.sender
     */

    function buyOrder(uint256 orderIndex, address seller) external payable {
        //cant buy from zero address
        if(seller == address(0)) {
            revert TokenDivider__InvalidSeller();
        }
    
        SellOrder memory order = s_userToSellOrders[seller][orderIndex];

        //if paid less than order price, revert
        if(msg.value < order.price) {
            revert TokenDivider__IncorrectEtherAmount();
        }

        //fee is 1% of the order price, 
        //seller fee is half of the fee
        // let say orderprice is 1e18, (1eth), fee is 1e16 (0.1eth), seller fee is 5e15 (0.05eth)
        uint256 fee = order.price / 100;
        uint256 sellerFee = fee / 2;


        //if the msg.sender doesnt have enough ether to pay the fees, revert
        if(msg.value <  order.price + sellerFee) {
            revert TokenDivider__InsuficientEtherForFees();
        }

        //(e): statechange: add the amount of erc20 tokens to the msg.sender
        balances[msg.sender][order.erc20Address] += order.amount;

        //(e): statechange: remove the order from the user's orders, 
        //but there might be issue here.
        // example: lets say the seller have 5 orders, and the buyer buys the second order,
        // [1,2,3,4,5] -> [1,5,3,4], the order is removed from the array, but the index of the orders are not updated

        //s_userToSellOrders[seller][orderIndex] is the order to be removed
        //s_userToSellOrders[seller][s_userToSellOrders[seller].length - 1] is the last order in the array
        //this is done to keep the array ordered
        s_userToSellOrders[seller][orderIndex] = s_userToSellOrders[seller][s_userToSellOrders[seller].length - 1];
        s_userToSellOrders[seller].pop();
        
        emit OrderSelled(msg.sender, order.price);
        
        // Transfer The Ether
        //interact: transfer the ether to the seller
        (bool success, ) = payable(order.seller).call{value: (order.price - sellerFee)}("");

        if(!success) {
            revert TokenDivider__TransferFailed();
        }
        //interact: transfer the fee collected to the owner()
        (bool taxSuccess, ) = payable(owner()).call{value: fee}("");


        //if the transfer of the fee failed, revert
        if(!taxSuccess) {
            revert TokenDivider__TransferFailed();
        }

        //interact: transfer the erc20 tokens to the msg.sender
        IERC20(order.erc20Address).transfer(msg.sender, order.amount); 

    }

    /** Getters */

    function getBalanceOf(address user, address token) public view returns(uint256) {
        s
    }

    function getErc20TotalMintedAmount(address erc20) public view returns(uint256) {
        return erc20ToMintedAmount[erc20];
    }

    function getErc20InfoFromNft(address nft) public view returns(ERC20Info memory) {
        return nftToErc20Info[nft];
    }

    function getOrderPrice(address seller, uint256 index) public view returns(uint256 price) {
        price =  s_userToSellOrders[seller][index].price;
    }

}