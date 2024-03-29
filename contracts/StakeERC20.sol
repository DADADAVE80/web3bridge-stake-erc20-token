// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./IERC20.sol";

error NOT_OWNER();
error AMOUNT_IS_ZERO();
error REWARD_DURATION_NOT_FINISHED();
error REWARD_AMOUNT_MORE_THAN_BALANCE();
error REWARD_RATE_IS_ZERO();

contract StakeERC20 {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;

    address public owner;

    uint256 public duration;
    uint256 public finishAt; //end of stake duration
    uint256 public updatedAt; // next reward session
    uint256 public rewardRate; // rate of rewards per second
    uint256 public rewardPerTokenStored; //

    mapping(address => uint256) public userRewardPerTokenStaked;
    mapping(address => uint256) public rewards;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    modifier onlyOwner() {
        require(msg.sender == owner, NOT_OWNER());
        _;
    }

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();
        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenStaked[_account] = rewardPerTokenStored;
        }
        _;
    }

    constructor(address _stakingToken, address _rewardToken) {
        owner = msg.sender;
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }

    function setRewardDuration(uint _duration) external onlyOwner {
        require(finishAt < block.timestamp, REWARD_DURATION_NOT_FINISHED());
        duration = _duration;
    }

    function notifyRewardAmount(uint _amount) external onlyOwner updateReward(address(0)) {
        // check if reward time has elapsed
        if (block.timestamp > finishAt) {
            rewardRate = _amount / duration;
        } else {
            uint remainingRewards = rewardRate * (finishAt - block.timestamp);
            rewardRate = (remainingRewards + _amount) / duration;
        }

        require(rewardRate > 0, REWARD_RATE_IS_ZERO());
        require(rewardRate * duration <= rewardToken.balanceOf(address(this)), REWARD_AMOUNT_MORE_THAN_BALANCE());

        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;
    }

    function stake(uint256 _amount) external updateReward(msg.sender) {
        require(_amount > 0, AMOUNT_IS_ZERO());
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;
    }

    function withdraw(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, AMOUNT_IS_ZERO());
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
        stakingToken.transfer(msg.sender, _amount);
    }

    function lastTimeRewardApplicable() public view returns (uint) {
        return _min(block.timestamp, finishAt);
    }

    function rewardPerToken() public view returns (uint) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) / totalSupply;
    }

    function earned(address _account) public view returns (uint) {
        return (balanceOf[_account] * (rewardPerToken() - userRewardPerTokenStaked[_account]) / 1e18) + rewards[_account];
    }

    function getReward() external updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.transfer(msg.sender, reward);
        }
    }

    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }
}