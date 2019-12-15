pragma solidity ^0.4.18;

// contract owner
contract Owned {
    address public owner;

    function Owned() public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function changeOwner(address newOwner) onlyOwner public {
        owner = newOwner;
    }
}

// standard ERC20Token
contract ERC20Token {
    uint256 public totalSupply;
    function balanceOf(address _owner) constant public returns (uint256 balance);
    function transfer(address _to, uint256 _value) public returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
    function approve(address _spender, uint256 _value) public returns (bool success);
    function allowance(address _owner, address _spender) constant public returns (uint256 remaining);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value)
}

contract XmbToken is ERC20Token, Owned {
    using SafeMath for uint256;
    string public name;
    string public symbol;
    uint8 public decimals;

    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) allowed;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function XmbToken(uint256 initialSupply, uint8 decimalUnits) public {
        name = "XmbToken";
        symbol = "XMB";
        balances[msg.sender] = initialSupply;
        decimals = decimalUnits;
    }

    function transfer(address _to, uint256 _value) onlyOwner public returns (bool success) {
	    if (balances[msg.sender] >= _value && balances[_to] + _value >= balances[_to]) {
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            Transfer(msg.sender, _to, _value);
            return true;
        }
	    return false;
	}

    function transferFrom(address _from, address _to, uint256 _value) onlyOwner public returns (bool success) {
        if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
            balances[_to] += _value;
            balances[_from] -= _value;
            allowed[_from][msg.sender] -= _value;
            Transfer(_from, _to, _value);
            return true;
        }
        return false;
    }

    function balanceOf(address _owner) constant public returns (uint256 balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant public returns (uint256 remaining) {
      return allowed[_owner][_spender];
    }

    function additional(uint256 _value) onlyOwner public returns (bool success) {
        if (balances[owner] + _value >= balances[owner]) {
            balances[owner] += _value;
            return true;
        }
        return false;
    }
}

contract Poetry is Owned {
    using SafeMath for uint256;

    struct Poem {
        string content;
        uint256 votes;
        uint voteCounts;
        mapping (address => bool) voted;
        address poetAddr;
    }

    XmbToken public xmb;
    bool public gameover = false;
    uint256 public poemReward = 15 ether;
    uint256 public voteReward = 85 ether;
    uint256 public eachVoterReward;
    Poem[] public poems;
    uint256 public maxVotes;
    uint[] public winners;
    uint256 public rechargeLimit = 30 ether;
    uint256 public rechargeRate = 1000;
    uint256 public startTime;
    uint256 public endTime;


    function Poetry(uint256 initialSupply, uint8 decimalUnits) public {
        startTime = now;
        endTime = startTime.add(31*1 days);
        xmb = new XmbToken(initialSupply, decimalUnits);
    }

    event PoemAdded(address from, uint poemId);
    event PoemVoted(address from, address to, uint poemId, uint256 value);
    event RewardPublished(address from, address to, uint256 value);
    event RechargeFaith(address indexed to, uint256 ethValue, uint256 distrbution, uint256 refund);
    event TokenIncrease(uint256 value, uint256 balance);

    modifier isNotOver() {
        require(now <= endTime);
        _;
    }

    modifier gameOver() {
        require(now > endTime);
        _;
    }

    function addPoem(string poemContent) isNotOver public returns (uint poemId) {
        poemId = poems.length++;

        Poem storage pm = poems[poemId];
        pm.content = poemContent;
        pm.votes = 0;
        pm.voteCounts = 0;
        pm.poetAddr = msg.sender;
        pm.voted[msg.sender] = true;

        PoemAdded(msg.sender, poemId);
    }

    function votePoem(uint poemId, uint256 _value) isNotOver public {
        require(xmb.balances(msg.sender) > 0 && _value <= xmb.balances(msg.sender));
        Poem storage pm = poems[poemId];
        require(!pm.voted[msg.sender]);
        pm.voted[msg.sender] = true;

        xmb.transferFrom(msg.sender, pm.poetAddr, _value);
        pm.votes += _value;
        pm.voteCounts ++;

        if (pm.votes > maxVotes) {
            maxVotes = pm.votes;
            resetWinner(poemId);
        } else if (pm.votes == maxVotes) {
            winners.push(poemId);
        }

        PoemVoted(msg.sender, pm.poetAddr, poemId, _value);
    }

    function reward() gameOver payable public {
        require((msg.sender == owner) && (this.balance > (poemReward + voteReward)));
        uint256 eachPoetReward = poemReward.div(winners.length);
        uint tmpVoteCounter = 0;
        for (uint i = 0; i <= winners.length-1; i++) {
            poems[winners[i]].poetAddr.transfer(eachPoetReward);
            RewardPublished(this, poems[winners[i]].poetAddr, eachPoetReward);
            tmpVoteCounter += poems[winners[i]].voteCounts;
        }
        eachVoterReward = voteReward.div(tmpVoteCounter);
    }

    function getVoterReward() gameOver public {
        for (uint i = 0; i <= winners.length-1; i++) {
            if (poems[winners[i]].voted[msg.sender]) {
                msg.sender.transfer(eachVoterReward);
                poems[winners[i]].voted[msg.sender] = false;
                RewardPublished(this, msg.sender, eachVoterReward);
            }
        }
    }

    function resetWinner(uint poemId) internal {
        if (winners.length > 0) {
            for (uint i = 0; i < winners.length-1; i++) {
                delete winners[i];
            }
        }
        winners.push(poemId);
    }

    function getBalance(address owner) view public returns (uint256) {
        return xmb.balanceOf(owner);
    }

    function buyXmb() payable public {
        uint256 distribution;
        uint256 _refund = 0;

        if ((msg.value > 0) && (tokenExchange(msg.value) < xmb.balances(this))) {
            if (msg.value > rechargeLimit) {
                _refund = msg.value.sub(rechargeLimit);
                msg.sender.transfer(_refund);
                distribution = tokenExchange(rechargeLimit);
            } else {
                distribution = tokenExchange(msg.value);
            }
            xmb.transfer(msg.sender, distribution);
        }
        RechargeFaith(msg.sender, msg.value, distribution, _refund);
    }

    function tokenExchange(uint256 inputAmount) internal view returns (uint256) {
        return inputAmount.mul(rechargeRate);
    }

    function tokenIncrease(uint256 value) payable public {
        require(msg.sender == owner);
        xmb.additional(value);
        TokenIncrease(value, this.balance);
    }

}

library SafeMath {
    function mul(uint a, uint b) internal pure returns (uint) {
        uint c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function div(uint a, uint b) internal pure returns (uint) {
        uint c = a / b;
        return c;
    }

    function sub(uint a, uint b) internal pure returns (uint) {
        assert(b <= a);
        return a - b;
    }

    function add(uint a, uint b) internal pure returns (uint) {
        uint c = a + b;
        assert(c >= a);
        return c;
    }
}


