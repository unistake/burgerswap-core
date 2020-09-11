// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >= 0.5.1;

struct Config {
        uint minValue;
        uint maxValue;
        uint maxSpan;
        uint value;
        uint enable;  // 0:disable, 1: enable
    }

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}

interface IDemaxConfig {
    function tokenCount() external view returns(uint);
    function tokenList(uint index) external view returns(address);
    function getConfigValue(bytes32 _name) external view returns (uint);
    function configs(bytes32 name) external view returns(Config memory);
    function tokenStatus(address token) external view returns(uint);
}

interface IDemaxPlatform {
    function existPair(address tokenA, address tokenB) external view returns (bool);
    function swapPrecondition(address token) external view returns (bool);
    function getReserves(address tokenA, address tokenB) external view returns (uint256, uint256);
}

interface IDemaxFactory {
    function getPlayerPairCount(address player) external view returns(uint);
    function playerPairs(address user, uint index) external view returns(address);
}

interface IDemaxPair {
    function token0() external view returns(address);
    function token1() external view returns(address);
    function getReserves() external view returns(uint, uint, uint);
    function lastMintBlock(address user) external view returns(uint); 
}

interface IDemaxGovernance {
    function ballotCount() external view returns(uint);
    function rewardOf(address ballot) external view returns(uint);
    function tokenBallots(address ballot) external view returns(address);
    function ballotTypes(address ballot) external view returns(uint);
    function ballots(uint index) external view returns(address);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner) external view returns (uint);
    function configBallots(address ballot) external view returns (bytes32);
    function collectUsers(address ballot, address user) external view returns(uint);
}

interface IDemaxBallot {
    struct Voter {
        uint weight; // weight is accumulated by delegation
        bool voted;  // if true, that person already voted
        address delegate; // person delegated to
        uint vote;   // index of the voted proposal
    }
    function subject() external view returns(string memory);
    function content() external view returns(string memory);
    function endBlockNumber() external view returns(uint);
    function createTime() external view returns(uint);
    function proposals(uint index) external view returns(uint);
    function ended() external view returns (bool);
    function value() external view returns (uint);
    function voters(address user) external view returns (Voter memory);
}

pragma experimental ABIEncoderV2;

contract DemaxQuery {
    bytes32 public constant PRODUCE_DGAS_RATE = bytes32('PRODUCE_DGAS_RATE');
    bytes32 public constant SWAP_FEE_PERCENT = bytes32('SWAP_FEE_PERCENT');
    bytes32 public constant LIST_DGAS_AMOUNT = bytes32('LIST_DGAS_AMOUNT');
    bytes32 public constant UNSTAKE_DURATION = bytes32('UNSTAKE_DURATION');
    bytes32 public constant REMOVE_LIQUIDITY_DURATION = bytes32('REMOVE_LIQUIDITY_DURATION');
    bytes32 public constant TOKEN_TO_DGAS_PAIR_MIN_PERCENT = bytes32('TOKEN_TO_DGAS_PAIR_MIN_PERCENT');
    bytes32 public constant LIST_TOKEN_FAILURE_BURN_PRECENT = bytes32('LIST_TOKEN_FAILURE_BURN_PRECENT');
    bytes32 public constant LIST_TOKEN_SUCCESS_BURN_PRECENT = bytes32('LIST_TOKEN_SUCCESS_BURN_PRECENT');
    bytes32 public constant PROPOSAL_DGAS_AMOUNT = bytes32('PROPOSAL_DGAS_AMOUNT');
    bytes32 public constant VOTE_DURATION = bytes32('VOTE_DURATION');
    bytes32 public constant VOTE_REWARD_PERCENT = bytes32('VOTE_REWARD_PERCENT');
    bytes32 public constant PAIR_SWITCH = bytes32('PAIR_SWITCH');
    bytes32 public constant TOKEN_PENGDING_SWITCH = bytes32('TOKEN_PENGDING_SWITCH');
    bytes32 public constant TOKEN_PENGDING_TIME = bytes32('TOKEN_PENGDING_TIME');

    address public configAddr;
    address public platform;
    address public factory;
    address public owner;
    address public governance;
    
    struct Proposal {
        address ballotAddress;
        address tokenAddress;
        string subject;
        string content;
        uint createTime;
        uint endBlock;
        bool end;
        uint YES;
        uint NO;
        uint totalReward;
        uint ballotType;
        uint weight;
        bool minted;
        bool voted;
        uint voteIndex;
        bool audited;
        uint value;
        bytes32 key;
    }
    
    struct Token {
        address tokenAddress;
        string symbol;
        uint decimal;
        uint balance;
        uint allowance;
        uint allowanceGov;
        uint status;
    }
    
    struct Liquidity {
        address pair;
        uint balance;
        uint totalSupply;
        uint lastBlock;
    }
    
    constructor(address _config, address _platform, address _factory, address _governance) public {
        configAddr = _config;
        platform = _platform;
        factory = _factory;
        governance = _governance;
        owner = msg.sender;
    }
    
    function upgrade(address _config, address _platform, address _factory, address _governance) public {
        require(owner == msg.sender);
        configAddr = _config;
        platform = _platform;
        factory = _factory;
        governance = _governance;
    }
   
    function queryTokenList() public view returns (Token[] memory token_list) {
        uint count = IDemaxConfig(configAddr).tokenCount();
        if(count > 0) {
            token_list = new Token[](count);
            for(uint i = 0;i < count;i++) {
                Token memory tk;
                tk.tokenAddress = IDemaxConfig(configAddr).tokenList(i);
                tk.symbol = IERC20(tk.tokenAddress).symbol();
                tk.decimal = IERC20(tk.tokenAddress).decimals();
                tk.balance = IERC20(tk.tokenAddress).balanceOf(msg.sender);
                tk.allowance = IERC20(tk.tokenAddress).allowance(msg.sender, platform);
                tk.allowanceGov = IERC20(tk.tokenAddress).allowance(msg.sender, governance);
                tk.status = IDemaxConfig(configAddr).tokenStatus(tk.tokenAddress);
                token_list[i] = tk;
            }
        }
    }
    
    function queryLiquidityList() public view returns (Liquidity[] memory liquidity_list) {
        uint count = IDemaxFactory(factory).getPlayerPairCount(msg.sender);
        if(count > 0) {
            liquidity_list = new Liquidity[](count);
            for(uint i = 0;i < count;i++) {
                Liquidity memory l;
                l.pair = IDemaxFactory(factory).playerPairs(msg.sender, i);
                l.balance = IERC20(l.pair).balanceOf(msg.sender);
                l.totalSupply = IERC20(l.pair).totalSupply();
                l.lastBlock = IDemaxPair(l.pair).lastMintBlock(msg.sender);
                liquidity_list[i] = l;
            }
        }
    }
    
    function queryPairListInfo(address[] memory pair_list) public view returns (address[] memory token0_list, address[] memory token1_list,
    uint[] memory reserve0_list, uint[] memory reserve1_list) {
        uint count = pair_list.length;
        if(count > 0) {
            token0_list = new address[](count);
            token1_list = new address[](count);
            reserve0_list = new uint[](count);
            reserve1_list = new uint[](count);
            for(uint i = 0;i < count;i++) {
                token0_list[i] = IDemaxPair(pair_list[i]).token0();
                token1_list[i] = IDemaxPair(pair_list[i]).token1();
                (reserve0_list[i], reserve1_list[i], ) = IDemaxPair(pair_list[i]).getReserves();
            }
        }
    }
    
    function queryPairReserve(address[] memory token0_list, address[] memory token1_list) public
    view returns (uint[] memory reserve0_list, uint[] memory reserve1_list, bool[] memory exist_list) {
        uint count = token0_list.length;
        if(count > 0) {
            reserve0_list = new uint[](count);
            reserve1_list = new uint[](count);
            exist_list = new bool[](count);
            for(uint i = 0;i < count;i++) {
                if(IDemaxPlatform(platform).existPair(token0_list[i], token1_list[i])) {
                    (reserve0_list[i], reserve1_list[i]) = IDemaxPlatform(platform).getReserves(token0_list[i], token1_list[i]);
                    exist_list[i] = true;
                } else {
                    exist_list[i] = false;
                }
            }
        }
    }
    
    function queryConfig() public view returns (uint fee_percent, uint proposal_amount, uint unstake_duration, uint remove_duration, uint list_token_amount){
        fee_percent = IDemaxConfig(configAddr).getConfigValue(SWAP_FEE_PERCENT);
        proposal_amount = IDemaxConfig(configAddr).getConfigValue(PROPOSAL_DGAS_AMOUNT);
        unstake_duration = IDemaxConfig(configAddr).getConfigValue(UNSTAKE_DURATION);
        remove_duration = IDemaxConfig(configAddr).getConfigValue(REMOVE_LIQUIDITY_DURATION);
        list_token_amount = IDemaxConfig(configAddr).getConfigValue(LIST_DGAS_AMOUNT);
    }
    
    function queryCondition(address[] memory path_list) public view returns (uint){
        uint count = path_list.length;
        for(uint i = 0;i < count;i++) {
            if(!IDemaxPlatform(platform).swapPrecondition(path_list[i])) {
                return i + 1;
            }
        }
        
        return 0;
    }
    
    function generateProposal(address ballot_address) public view returns (Proposal memory proposal){
        proposal.subject = IDemaxBallot(ballot_address).subject();
        proposal.content = IDemaxBallot(ballot_address).content();
        proposal.createTime = IDemaxBallot(ballot_address).createTime();
        proposal.endBlock = IDemaxBallot(ballot_address).endBlockNumber();
        proposal.end = block.number > IDemaxBallot(ballot_address).endBlockNumber() ? true: false;
        proposal.audited = IDemaxBallot(ballot_address).ended();
        proposal.YES = IDemaxBallot(ballot_address).proposals(1);
        proposal.NO = IDemaxBallot(ballot_address).proposals(2);
        proposal.totalReward = IDemaxGovernance(governance).rewardOf(ballot_address);
        proposal.ballotAddress = ballot_address;
        proposal.voted = IDemaxBallot(ballot_address).voters(msg.sender).voted;
        proposal.voteIndex = IDemaxBallot(ballot_address).voters(msg.sender).vote;
        proposal.weight = IDemaxBallot(ballot_address).voters(msg.sender).weight;
        proposal.minted = IDemaxGovernance(governance).collectUsers(ballot_address, msg.sender) == 1;
        proposal.ballotType = IDemaxGovernance(governance).ballotTypes(ballot_address);
        proposal.tokenAddress = IDemaxGovernance(governance).tokenBallots(ballot_address);
        proposal.value = IDemaxBallot(ballot_address).value();
        if(proposal.ballotType == 1) {
            proposal.key = IDemaxGovernance(governance).configBallots(ballot_address);
        }
    }
    
    function queryTokenItemInfo(address token) public view returns (string memory symbol, uint decimal, uint totalSupply, uint balance, uint allowance) {
        symbol = IERC20(token).symbol();
        decimal = IERC20(token).decimals();
        totalSupply = IERC20(token).totalSupply();
        balance = IERC20(token).balanceOf(msg.sender);
        allowance = IERC20(token).allowance(msg.sender, platform);
    }
    
    function queryProposalList() public view returns (Proposal[] memory proposal_list){
        uint count = IDemaxGovernance(governance).ballotCount();
        proposal_list = new Proposal[](count);
        for(uint i = 0;i < count;i++) {
            address ballot_address = IDemaxGovernance(governance).ballots(i);
            proposal_list[count - i - 1] = generateProposal(ballot_address);
        }
    }
    
    function queryConfigInfo(bytes32 name) public view returns (Config memory config_item){
        config_item = IDemaxConfig(configAddr).configs(name);
    }
    
    function queryStakeInfo() public view returns (uint stake_amount, uint stake_block) {
        stake_amount = IDemaxGovernance(governance).balanceOf(msg.sender);
        stake_block = IDemaxGovernance(governance).allowance(msg.sender);
    }
}