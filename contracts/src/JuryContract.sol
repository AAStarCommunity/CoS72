// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title COS72 Jury Contract
 * @notice Standalone jury system for dispute resolution
 * @dev Independent contract that can be used by TaskContract or other systems
 */
contract JuryContract is Ownable, ReentrancyGuard {

    // ==================== CONSTANTS ====================
    uint256 private constant BPS_DENOMINATOR = 10000;
    uint256 public constant MIN_JURY_STAKE = 10 ether; // 10 GToken
    uint256 public constant DISPUTE_FEE_RATE = 500; // 5%
    uint256 public constant PROTOCOL_FEE_RATE = 100; // 1%
    uint256 public constant JURY_REWARD_RATE = 200; // 2%
    uint256 public constant PROTOCOL_SHARE = 6000; // 60%
    uint256 public constant JURY_SHARE = 2000; // 20%

    // ==================== STRUCTS ====================
    struct JuryMember {
        address memberAddress;
        uint256 stakedAmount;
        uint256 reputation;
        uint256 casesParticipated;
        uint256 casesResolved;
        uint256 successRate;
        bool isActive;
        uint256 joinedAt;
        uint256 lastActivity;
    }

    struct Dispute {
        uint256 taskId;
        address challenger;
        address respondent;
        address[3] selectedJury;
        uint256 disputeFee;
        uint256 juryReward;
        string description;
        uint256[3] votes;
        uint256 finalDecision;
        bool isResolved;
        uint256 createdAt;
        uint256 resolvedAt;
    }

    // ==================== IMMUTABLES ====================
    address public immutable GTOKEN;
    address public immutable TREASURY;
    uint256 public immutable TASK_CONTRACT;

    // ==================== STATE VARIABLES ====================
    uint256 private _disputeCounter;
    mapping(address => JuryMember) public juryMembers;
    address[] public activeJuryMembers;
    mapping(uint256 => Dispute) public disputes;
    mapping(address => bool) public authorizedContracts;

    // ==================== ARRAYS ====================
    address[] public allJuryMembers;

    // ==================== EVENTS ====================
    event JuryMemberJoined(address indexed member, uint256 stakedAmount);
    event JuryMemberLeft(address indexed member, uint256 returnedAmount);
    event DisputeInitiated(uint256 indexed taskId, address indexed challenger, address[3] selectedJury, uint256 disputeFee);
    event JuryVoteCast(uint256 indexed taskId, address indexed juror, uint256 vote);
    event DisputeResolved(uint256 indexed taskId, uint256 finalDecision, address[3] juryMembers, uint256 assigneeReward, uint256 publisherRefund);
    event ContractAuthorized(address indexed contract, address indexed authorizer);
    event ContractRevoked(address indexed contract, address indexed revoker);

    // ==================== MODIFIERS ====================
    modifier onlyJuryMember() {
        require(juryMembers[msg.sender].isActive, "Not an active jury member");
        _;
    }

    modifier onlyAuthorizedContract() {
        require(authorizedContracts[msg.sender], "Not authorized contract");
        _;
    }

    modifier disputeExists(uint256 disputeId) {
        require(disputes[disputeId].challenger != address(0), "Dispute does not exist");
        _;
    }

    // ==================== CONSTRUCTOR ====================
    constructor(
        address gToken,
        address treasury,
        address taskContract
    ) Ownable(msg.sender) {
        GTOKEN = gToken;
        TREASURY = treasury;
        TASK_CONTRACT = taskContract;
        _disputeCounter = 1;

        // Authorize task contract to use jury system
        authorizedContracts[taskContract] = true;
    }

    // ==================== JURY MANAGEMENT ====================

    function joinJury() external nonReentrant {
        require(!juryMembers[msg.sender].isActive, "Already a jury member");

        require(
            IERC20(GTOKEN).transferFrom(msg.sender, address(this), MIN_JURY_STAKE),
            "Insufficient GToken stake"
        );

        juryMembers[msg.sender] = JuryMember({
            memberAddress: msg.sender,
            stakedAmount: MIN_JURY_STAKE,
            reputation: 5000, // Start with 50%
            casesParticipated: 0,
            casesResolved: 0,
            successRate: 0,
            isActive: true,
            joinedAt: block.timestamp,
            lastActivity: block.timestamp
        });

        activeJuryMembers.push(msg.sender);
        allJuryMembers.push(msg.sender);

        emit JuryMemberJoined(msg.sender, MIN_JURY_STAKE);
    }

    function leaveJury() external nonReentrant onlyJuryMember {
        JuryMember storage member = juryMembers[msg.sender];
        require(member.casesParticipated == 0, "Have active dispute cases");

        // Return stake
        require(
            IERC20(GTOKEN).transfer(msg.sender, member.stakedAmount),
            "Stake return failed"
        );

        // Remove from active members
        _removeFromActiveJury(msg.sender);

        // Mark as inactive
        member.isActive = false;

        emit JuryMemberLeft(msg.sender, member.stakedAmount);
    }

    // ==================== DISPUTE MANAGEMENT ====================

    function initiateDispute(
        uint256 taskId,
        address challenger,
        address respondent,
        string calldata description
    ) external payable onlyAuthorizedContract nonReentrant {
        uint256 disputeId = _disputeCounter++;

        require(msg.value >= (MIN_JURY_STAKE * DISPUTE_FEE_RATE) / BPS_DENOMINATOR, "Insufficient dispute fee");

        address[3] memory selectedJury = _selectRandomJury();

        uint256 juryReward = (msg.value * JURY_REWARD_RATE) / BPS_DENOMINATOR;

        disputes[disputeId] = Dispute({
            taskId: taskId,
            challenger: challenger,
            respondent: respondent,
            selectedJury: selectedJury,
            disputeFee: msg.value,
            juryReward: juryReward,
            description: description,
            votes: [uint256(0), uint256(0), uint256(0)],
            finalDecision: 0,
            isResolved: false,
            createdAt: block.timestamp,
            resolvedAt: 0
        });

        emit DisputeInitiated(taskId, challenger, selectedJury, msg.value);
    }

    function voteOnDispute(uint256 disputeId, uint256 votePercentage)
        external
        onlyJuryMember
        disputeExists(disputeId)
        nonReentrant
    {
        Dispute storage dispute = disputes[disputeId];

        require(votePercentage <= 100, "Vote must be 0-100%");

        // Find juror's slot
        for (uint i = 0; i < 3; i++) {
            if (dispute.selectedJury[i] == msg.sender) {
                dispute.votes[i] = votePercentage;
                break;
            }
        }

        emit JuryVoteCast(disputeId, msg.sender, votePercentage);

        // Check if all jury have voted
        if (_allJuryVoted(disputeId)) {
            _resolveDispute(disputeId);
        }
    }

    // ==================== REPUTATION SYSTEM ====================

    function getReputationScore(address juror) external view returns (uint256) {
        JuryMember storage juror = juryMembers[juror];

        if (!juror.isActive) return juror.reputation;

        uint256 score = 0;

        // Success rate weight: 40%
        score += (juror.successRate * 40) / BPS_DENOMINATOR;

        // Activity weight: 30%
        score += (juror.casesResolved * 100 > 3000) ? 3000 : juror.casesResolved * 100;

        // Tenure weight: 20%
        uint256 tenure = block.timestamp - juror.joinedAt;
        score += (tenure > 365 days ? 2000 : tenure * 6 / 365 days);

        // Participation weight: 10%
        score += juror.isActive ? 1000 : 0;

        return Math.min(score, 10000);
    }

    // ==================== INTERNAL FUNCTIONS ====================

    function _selectRandomJury() internal view returns (address[3] memory) {
        require(activeJuryMembers.length >= 3, "Insufficient jury members");

        address[3] memory selected;
        uint256 seed = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            _disputeCounter
        )));

        uint256[] memory availableIndices = new uint256[](activeJuryMembers.length);
        for (uint i = 0; i < activeJuryMembers.length; i++) {
            availableIndices[i] = i;
        }

        // Fisher-Yates shuffle
        for (uint i = 0; i < 3; i++) {
            uint256 randomIndex = (seed + i) % (activeJuryMembers.length - i);
            uint256 selectedIndex = availableIndices[randomIndex];
            selected[i] = activeJuryMembers[selectedIndex];

            // Move last element to current position
            availableIndices[randomIndex] = availableIndices[activeJuryMembers.length - 1 - i];
        }

        return selected;
    }

    function _allJuryVoted(uint256 disputeId) internal view returns (bool) {
        Dispute storage dispute = disputes[disputeId];

        for (uint i = 0; i < 3; i++) {
            if (dispute.selectedJury[i] != address(0) && dispute.votes[i] == 0) {
                return false;
            }
        }
        return true;
    }

    function _resolveDispute(uint256 disputeId) internal {
        Dispute storage dispute = disputes[disputeId];

        uint256 totalVotes = 0;
        uint256 voterCount = 0;

        for (uint i = 0; i < 3; i++) {
            if (dispute.votes[i] > 0) {
                totalVotes += dispute.votes[i];
                voterCount++;
            }
        }

        require(voterCount > 0, "No valid votes recorded");
        uint256 finalDecision = totalVotes / voterCount;

        // Update juror reputation
        for (uint i = 0; i < 3; i++) {
            if (dispute.selectedJury[i] != address(0)) {
                JuryMember storage juror = juryMembers[dispute.selectedJury[i]];
                juror.casesParticipated++;
                juror.lastActivity = block.timestamp;

                if (dispute.isResolved == false) {
                    juror.casesResolved++;
                    juror.successRate = ((juror.successRate * juror.casesParticipated) + 10000) / (juror.casesParticipated + 1);
                }
            }
        }

        dispute.finalDecision = finalDecision;
        dispute.isResolved = true;
        dispute.resolvedAt = block.timestamp;

        // Calculate reward distribution
        uint256 juryRewardPerJuror = dispute.juryReward / 3;
        for (uint i = 0; i < 3; i++) {
            if (dispute.selectedJury[i] != address(0)) {
                require(
                    IERC20(GTOKEN).transfer(dispute.selectedJury[i], juryRewardPerJuror),
                    "Jury reward transfer failed"
                );
            }
        }

        // Send protocol fee to treasury
        uint256 protocolFee = (dispute.disputeFee * PROTOCOL_FEE_RATE) / BPS_DENOMINATOR;
        require(
            IERC20(GTOKEN).transfer(TREASURY, protocolFee),
            "Protocol fee transfer failed"
        );

        emit DisputeResolved(disputeId, finalDecision, dispute.selectedJury, 0, dispute.disputeFee - protocolFee);
    }

    function _removeFromActiveJury(address member) internal {
        uint256 length = activeJuryMembers.length;
        for (uint i = 0; i < length; i++) {
            if (activeJuryMembers[i] == member) {
                activeJuryMembers[i] = activeJuryMembers[length - 1];
                break;
            }
        }
    }

    // ==================== VIEW FUNCTIONS ====================

    function getDispute(uint256 disputeId) external view returns (Dispute memory) {
        return disputes[disputeId];
    }

    function getJuryMember(address member) external view returns (JuryMember memory) {
        return juryMembers[member];
    }

    function getActiveJuryCount() external view returns (uint256) {
        return activeJuryMembers.length;
    }

    function getAllJuryMembers() external view returns (address[] memory) {
        return allJuryMembers;
    }

    function isJuryMember(address account) external view returns (bool) {
        return juryMembers[account].isActive;
    }

    // ==================== OWNER FUNCTIONS ====================

    function authorizeContract(address contract) external onlyOwner {
        authorizedContracts[contract] = true;
        emit ContractAuthorized(contract, msg.sender);
    }

    function revokeContractAuthorization(address contract) external onlyOwner {
        authorizedContracts[contract] = false;
        emit ContractRevoked(contract, msg.sender);
    }

    // ==================== EMERGENCY FUNCTIONS ====================

    function emergencyWithdraw() external onlyOwner {
        (bool success, ) = IERC20(GTOKEN).transfer(msg.sender, IERC20(GTOKEN).balanceOf(address(this)));
        require(success, "Emergency withdraw failed");
    }
}
```

现在编译这两个精简的合约：
<file_path>
my-exploration/projects/Cos72/contracts/src/contracts/JuryContract.sol
</file_path>

<edit_description>
Compile both streamlined contracts
</edit_description>
