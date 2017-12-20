pragma solidity ^0.4.18;

interface tokenRecipient { 
    function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) public;
}

contract owned {
    address public owner;
    
    function owned() public {
        owner = msg.sender;
    }
    
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    
    function transferOwnership(address newOwner) public onlyOwner {
        owner = newOwner;
    }
}

contract TokenERC20 is owned {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);
    
    function TokenERC20(
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol
    ) public {
        name = tokenName;
        symbol = tokenSymbol;
        
        totalSupply = initialSupply * 10 ** uint256(decimals);
        balanceOf[msg.sender] = totalSupply;
    }
    
    function mintTokens(address target, uint256 mintedAmount) public onlyOwner {
        // TODO: value overflow
        require(balanceOf[target] + mintedAmount > balanceOf[target]);
        balanceOf[target] += mintedAmount;
        totalSupply += mintedAmount;
        Transfer(0, owner, mintedAmount);
        Transfer(owner, target, mintedAmount);
    }
    
    function transfer(address _to, uint256 _value) public {
        _transfer(msg.sender, _to, _value);
    }
    
    function _transfer(address _from, address _to, uint256 _value) private {
        require(_to != 0x0);
        require(balanceOf[_from] >= _value);
        require(balanceOf[_to] + _value > balanceOf[_to]); // Overflow is interesting
        
        uint previousBalances = balanceOf[_from] + balanceOf[_to];
        
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        
        Transfer(_from, _to, _value);
        
        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
    }
    
    function transferFrom(address _from, address _to, uint256 value) public returns (bool success) {
        require(value < allowance[_from][msg.sender]);
        allowance[_from][msg.sender] -= value;
        _transfer(_from, _to, value);
        return true;
    }
    
    // weird but allow others to send tokens on your behalf
    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        return true;
    }
    
    function approveAndCall(address _spender, uint256 _value, bytes _extraData)
        public
        returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            // TODO: what does this even tdo?
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
    }
    
    // burn from myself
    function burn(uint256 amount) public returns (bool success) {
        require(amount <= balanceOf[msg.sender]);
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        Burn(msg.sender, amount);
        return true;
    }
    
    function burnFrom(address _from, uint256 amount) public returns (bool success) {
        require(amount <= allowance[_from][msg.sender]);
        require(amount <= balanceOf[_from]);
        balanceOf[_from] -= amount;
        allowance[_from][msg.sender] -= amount;
        totalSupply -= amount;
        Burn(_from, amount);
        return true;
    }
    
}


/******************************************/
/*       ADVANCED TOKEN STARTS HERE       */
/******************************************/


contract MegaUberToken is owned, TokenERC20 {
    
    uint256 public sellPrice;
    uint256 public buyPrice;
    uint256 public minBalanceForAccounts;

    mapping (address => bool) public frozenAccount;
    
    event FrozenFunds(address target, bool frozen);

    function MegaUberToken(
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol,
        address centralMinter
    ) TokenERC20 (
        initialSupply,
        tokenName,
        tokenSymbol
    ) public {
        if (centralMinter != 0) {
            owner = centralMinter;
        }
    }
    
    function _transfer(address _from, address _to, uint256 _value) private {
        require(_to != 0x0);
        require(balanceOf[_from] >= _value);
        require(balanceOf[_to] + _value > balanceOf[_to]); // Overflow is interesting
        require(!frozenAccount[_from]);
        require(!frozenAccount[_to]);
        
        if (msg.sender.balance < minBalanceForAccounts) {
            // This is confusing but it will multiply val by sellPrice again to find amount.
            sell((minBalanceForAccounts - msg.sender.balance) / sellPrice);
        }
        uint previousBalances = balanceOf[_from] + balanceOf[_to];
        
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        
        Transfer(_from, _to, _value);
        
        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
    }
    
    function setPrices(uint256 newSellPrice, uint256 newBuyPrice) public onlyOwner {
        sellPrice = newSellPrice;
        buyPrice = newBuyPrice;
    }
    
    // Called by user?
    // ether -> panda
    // The actual transfer to the contract happens somewhere else it hink.
    // One ether is 1000000000000000000 wei. So when setting prices for your token in ether, add 18 zeros at the end.
    function buy() public payable returns (uint) {
        uint amount = msg.value / buyPrice;
        // require(balanceOf[msg.sender] + amount > balanceOf[msg.sender]);
        // require(balanceOf[this] >= amount);
        
        balanceOf[this] -= amount;
        balanceOf[msg.sender] += amount;
        Transfer(this, msg.sender, amount);
        return amount;   
    }
    
    // panda -> ether
    function sell(uint amount) public payable returns (uint) {
        require(balanceOf[this] + amount > balanceOf[this]);
        require(balanceOf[msg.sender] >= amount);
        balanceOf[this] += amount;
        balanceOf[msg.sender] -= amount;
        // TODO: why * sellPrice?
        uint revenue = amount * sellPrice; // 10 @ .005 (.005 ether per share), but it's all wei
        require(msg.sender.send(revenue));
        Transfer(msg.sender, this, amount);
        return revenue;
    }
    
    function freezeAccount(address target, bool freeze) public onlyOwner {
        frozenAccount[target] = freeze;
        FrozenFunds(target, freeze);
    }
    
    function setMinBalanceForAccounts(uint256 minBalanceInFinney) public onlyOwner {
        minBalanceForAccounts = minBalanceInFinney * 1 finney;
    }
}
