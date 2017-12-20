pragma solidity ^0.4.18;

interface token {
    function transfer(address receiver, uint amount) public;
}

contract Crowdsale {
    token public tokenReward;
    uint price;
    
    event FundTransfer(address backer, uint amount, bool isContribution);

    function Crowdsale(
        uint priceInEther,
        address tokenRewardAddr
    ) payable public {
        price = priceInEther * 1 ether;
        tokenReward = token(tokenRewardAddr);
    }
    
    function pay() payable public {
        uint amount = msg.value;
        tokenReward.transfer(msg.sender, amount / price);
        FundTransfer(msg.sender, amount, true);
    }
}
