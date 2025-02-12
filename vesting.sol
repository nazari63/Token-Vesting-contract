// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenVesting is Ownable {
    IERC20 public token;
    uint256 public startTime;
    uint256 public duration;
    
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 releaseTime;
    }

    mapping(address => VestingSchedule) public vestingSchedules;
    
    event TokensReleased(address indexed beneficiary, uint256 amount);

    constructor(IERC20 _token, uint256 _duration) {
        token = _token;
        startTime = block.timestamp;
        duration = _duration;
    }

    // Set vesting schedule for an address
    function setVestingSchedule(address beneficiary, uint256 totalAmount, uint256 releaseTime) external onlyOwner {
        require(vestingSchedules[beneficiary].totalAmount == 0, "Vesting schedule already exists for this address");
        require(totalAmount > 0, "Amount must be greater than 0");
        require(releaseTime > block.timestamp, "Release time must be in the future");

        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: totalAmount,
            releasedAmount: 0,
            startTime: block.timestamp,
            releaseTime: releaseTime
        });
    }

    // Release vested tokens to the beneficiary
    function releaseTokens() external {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        
        require(schedule.totalAmount > 0, "No vesting schedule found for this address");
        require(block.timestamp >= schedule.releaseTime, "Tokens are not yet releasable");
        
        uint256 releasableAmount = getReleasableAmount(msg.sender);
        require(releasableAmount > 0, "No tokens available for release");

        schedule.releasedAmount += releasableAmount;
        token.transfer(msg.sender, releasableAmount);

        emit TokensReleased(msg.sender, releasableAmount);
    }

    // Calculate releasable amount based on the time passed
    function getReleasableAmount(address beneficiary) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];

        if (block.timestamp < schedule.releaseTime) {
            return 0;
        }

        uint256 vestedAmount = (schedule.totalAmount * (block.timestamp - schedule.startTime)) / duration;
        uint256 releasableAmount = vestedAmount - schedule.releasedAmount;

        return releasableAmount;
    }

    // Get total vesting amount for an address
    function getTotalVestedAmount(address beneficiary) public view returns (uint256) {
        return vestingSchedules[beneficiary].totalAmount;
    }

    // Get released amount for an address
    function get