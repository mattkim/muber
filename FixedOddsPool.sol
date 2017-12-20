pragma solidity ^0.4.18;

// TODO: modifiers
// TODO: events
// TODO: integrate with web app
// TODO: inheritance
// TODO: division
// TODO: edit token after creation
// TODO: handle storage vs. memory 

interface token {
    function transfer(address receiver, uint amount);
}

contract FixedOddsPool {

    struct Player {
        address addr;
        uint id;
        string name;
        uint amount;
        uint optionId;
        uint multiplier;
        bool isPooled;
        bool approved;
    }
    
    struct Option {
        string name;
        uint odds;
    }
    
    struct Pool {
        uint multiplier;
        uint[] matchedPlayers;
    }

    // Need pools to have matches.
    // TODO: pools is private
    // Pools maybe optimizes match time.
    Pool[] public pools; 
    Pool[] public pendingPools; 
    Player[] public players;
    Option[] public options;
    uint public winningOptionId;
    uint public addPlayerExpiration;
    bool public contractClosed;
    token public tokenReward;
    mapping (address => uint) public addrToPlayerId;

    string public name;
    uint public fees;
    address public owner;
    
    function FixedOddsPool(string thisName) public {
        // TODO: only token owners can create contracts.
        name = thisName;
        owner = msg.sender;
        winningOptionId = 0; // this is null value;
        contractClosed = false;
        addPlayerExpiration = now + 600; // now + 10 minutes;
        players.length++; // 0 is always the "contract" owner.
        options.length++; // double check this doesn't break stuff
    }
    
    function closeContract() public {
        // A way to close the contract for safety.
        // Only the owner can close the contract
        // TODO: Maybe people can vote to close contract.
        // TODO: we can ban players and burn tokens if they are bad actors.
        require(owner == msg.sender);
        contractClosed = true;
    }
    
    function addOption(string optionName, uint optionOdds) public {
        require(!contractClosed);
        
        uint optionId = options.length++;
        Option newOption = options[optionId];
        newOption.name = optionName;
        newOption.odds = optionOdds;
    }
    
    function addPlayer(address playerAddr, string playerName, uint optionId, uint amount, uint multiplier) public {
        require(!contractClosed);
        // Can only add players if it's before expiration, but players can still vote.
        require(now < addPlayerExpiration);
        require(optionId != 0);
        require(multiplier != 0);
        
        uint playerId = addrToPlayerId[playerAddr];
        
        if (playerId == 0) {
            // Do we have to worry about concurrency?
            playerId = players.length++; 
            addrToPlayerId[playerAddr] = playerId;
        }
        
        Player p = players[playerId];
        p.addr = playerAddr;
        p.id = playerId;
        p.name = playerName;
        p.amount = amount;
        p.optionId = optionId;
        p.multiplier = multiplier;
        p.isPooled = false;
        p.approved = false;
    }
    
    function matchOrCreatePool(uint playerId) public {
        require(!contractClosed);
        
        Player p = players[playerId];
        
        // Don't double pool
        require(!p.isPooled);
        
        // Always try to match this player before creating a pool.
        if (matchPlayer(playerId)) {
            return;
        }
        
        Pool newPendingPool = pendingPools[pendingPools.length++];
        newPendingPool.multiplier = p.multiplier;
        uint[] matchedPlayers = newPendingPool.matchedPlayers;
        matchedPlayers.length = options.length;
        matchedPlayers[p.optionId] = playerId;
        p.isPooled = true;
    }
    
    function matchPlayer(uint playerId) private returns (bool) {
        require(!contractClosed);

        Player p = players[playerId];
        bool matched = false;
        for (uint i = 0; i < pendingPools.length; i++) {
            Pool pendingPool = pendingPools[i];
            if (
                pendingPool.multiplier == p.multiplier &&
                pendingPool.matchedPlayers[p.optionId] == 0
            ) {
                pendingPool.matchedPlayers[p.optionId] = playerId;
                p.isPooled = true;
                matched = true;
                break;
            }
        }
        
        return matched;
    }
    
    function vote(uint playerId, bool approved) public {
        require(!contractClosed);
        
        // TODO: there's an incentive to only allow one action
        // per users, because of fees.
        Player p = players[playerId];
        p.approved = approved;
    }
    
    function quorum() public returns (bool) {
        require(!contractClosed);
        for(uint i = 1; i < players.length; i++) {
            if (!players[i].approved) {
                return false;
            }
        }
        
        return true;
    }
    
    function setWinningOption(uint optionId) public {
        require(!contractClosed);
        require(owner == msg.sender);
        require(optionId != 0);
        winningOptionId = optionId;
    }
    
    function payPools() public {
        // Must only be called once.
        require(!contractClosed);
        require(owner == msg.sender);
        require(quorum());
        require(winningOptionId != 0); // Winning option not set.
        
        for (uint i = 0; i < pendingPools.length; i++) {
            Pool pendingPool = pendingPools[i];
            bool complete = true;
            
            // Make sure pool is complete.
            for(uint j = 1; j < pendingPool.matchedPlayers.length; j++) {
                if (pendingPool.matchedPlayers[j] == 0){
                    // Skip pools that don't have all options matched.
                    complete = false;
                }
            }
            
            // probably want to do some validation here.
            
            if (complete) {
                Player winner = players[pendingPool.matchedPlayers[winningOptionId]];

                for(uint k = 1; k < pendingPool.matchedPlayers.length; k++) {
                    if(k != winningOptionId) {
                        Player loser = players[pendingPool.matchedPlayers[k]];
                        // TODO: how to make participants pay into contract first?
                        // Does this automatically take money out of the contract?
                        // We need to make payable work.
                        // winner.addr.transfer(loser.amount);
                    }
                }
            }
            
        }
        
        // The main shutoff valve.
        // There might be a better way to do this.
        contractClosed = true;
    }
}
