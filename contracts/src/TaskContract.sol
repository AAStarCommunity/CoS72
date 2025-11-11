// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// PullPayment deprecated - using direct transfers instead
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title COS72 Task Contract
 * @notice Main contract for managing community tasks with jury dispute resolution
 * @dev Integrates with Registry for community validation and xPNTs for rewards
 */
contract TaskContract is Ownable, ReentrancyGuard {

    // ==================== ENUMS ====================

    /// @notice Task status throughout its lifecycle
    enum TaskStatus {
        Open,        // Task is open for applications
        InProgress,  // Task is being worked on
        InReview,    // Task submission is under review
        Completed,   // Task is completed and rewards paid
        Cancelled,   // Task was cancelled
        Disputed     // Task is under dispute resolution
    }

    /// @notice Task type determining who can complete it
    enum TaskType {
        Exclusive,    // Only assigned person can complete
        Open         // Anyone can submit and claim reward
    }

    /// @notice Dispute resolution status
    enum DisputeStatus {
        None,        // No dispute
        Pending,     // Dispute is active
        Resolved      // Dispute has been resolved
    }

    // ==================== STRUCTS ====================

    /// @notice Main task structure
    struct Task {
        uint256 id;                    // Unique task identifier
        address publisher;              // Task creator
        address communityAddress;        // Community this task belongs to
        address xPNTsToken;            // Community's xPNTs token address
        string title;                  // Task title
        string description;             // Task description
        uint256 reward;                // Reward amount in xPNTs
        uint256 deadline;              // Task deadline (timestamp)
        TaskStatus status;             // Current task status
        TaskType taskType;            // Type of task (Exclusive/Open)
        address assignee;              // Assigned person (Exclusive tasks)
        bool juryEnabled;             // Whether jury dispute resolution is enabled
        uint256 disputeFee;           // Dispute fee rate (5% = 500 basis points)
        uint256 createdAt;             // Creation timestamp
        uint256 updatedAt;             // Last update timestamp
        string submissionProof;        // Proof of task completion
        string reviewResult;           // Publisher's review feedback
        DisputeStatus disputeStatus;   // Current dispute status
        uint256 protocolFeeRate;      // Protocol fee rate (1% = 100 basis points)
    }

    /// @notice Jury member information
    struct JuryMember {
        address memberAddress;          // Member's wallet address
        uint256 stakedAmount;         // Amount of GToken staked (minimum 10)
        uint256 reputation;            // Reputation score (0-10000)
        uint256 casesParticipated;     // Total cases participated
        uint256 casesResolved;         // Total cases successfully resolved
        bool isActive;                 // Whether member is currently active
        uint256 joinedAt;              // When member joined the jury system
    }

    /// @notice Dispute case information
    struct DisputeCase {
        uint256 taskId;                // Associated task ID
        address challenger;            // Who initiated the dispute
        address respondent;             // Who is being challenged
        address[3] selectedJury;      // 3 randomly selected jury members
        uint256 disputeFee;           // Total dispute fee (10% of task reward)
        uint256 juryReward;            // Reward for jury members (2% of dispute fee)
        string description;            // Description of the dispute
        uint256[3] votes;           // Jury votes (0-100% for assignee)
        uint256 finalDecision;         // Final resolution percentage (0-100%)
        bool isResolved;              // Whether dispute is resolved
        uint256 createdAt;             // Dispute creation time
        uint256 resolvedAt;            // Dispute resolution time
    }

    /// @notice Publisher reputation tracking
    struct PublisherReputation {
        uint256 totalTasks;            // Total tasks published
        uint256 completedTasks;         // Total tasks completed
        uint256 totalRewards;          // Total rewards offered
        uint256 averageResponseTime;    // Average response time (seconds)
        uint256 disputeCount;          // Number of disputes initiated
        uint256 successRate;           // Success rate (basis points, 10000 = 100%)
        bool isActive;                 // Whether publisher is currently active
        uint256 lastActivity;          // Last activity timestamp
    }

    // ==================== CONSTANTS ====================

    /// @notice Minimum jury stake requirement
    uint256 public constant MIN_JURY_STAKE = 10 ether; // 10 GToken

    /// @notice Dispute fee rate for each party (5%)
    uint256 public constant DISPUTE_FEE_RATE = 500; // 5% (500/10000)

    /// @notice Total dispute fee (both parties)
    uint256 public constant TOTAL_DISPUTE_FEE = 1000; // 10% (1000/10000)

    /// @notice Jury reward rate from dispute fees
    uint256 public constant JURY_REWARD_RATE = 200; // 2% of dispute fee

    /// @notice Protocol fee rate on all rewards
    uint256 public constant PROTOCOL_FEE_RATE = 100; // 1% (100/10000)

    /// @notice Basis points denominator
    uint256 private constant BPS_DENOMINATOR = 10000;

    // ==================== STATE VARIABLES ====================

    /// @notice Registry contract address
    address public immutable REGISTRY;

    /// @notice GToken contract for jury staking
    address public immutable GTOKEN;

    /// @notice Protocol treasury address
    address public immutable TREASURY;

    /// @notice Task ID counter
    uint256 private _taskIdCounter;

    /// @notice Total number of jury members
    uint256 public totalJuryMembers;

    /// @notice Mapping from task ID to task data
    mapping(uint256 => Task) public tasks;

    /// @notice Mapping from task ID to dispute case
    mapping(uint256 => DisputeCase) public disputes;

    /// @notice Mapping from address to jury member data
    mapping(address => JuryMember) public juryMembers;

    /// @notice Mapping from address to publisher reputation
    mapping(address => PublisherReputation) public publisherReputations;

    /// @notice Array of active jury member addresses for random selection
    address[] public activeJuryMembers;

    /// @notice Mapping from community to publisher authorization
    mapping(address => mapping(address => bool)) public communityPublishers;

    // ==================== EVENTS ====================

    /// @notice Task published event
    event TaskPublished(
        uint256 indexed taskId,
        address indexed publisher,
        address indexed communityAddress,
        string title,
        uint256 reward,
        TaskType taskType,
        bool juryEnabled
    );

    /// @notice Task application event
    event TaskApplied(
        uint256 indexed taskId,
        address indexed applicant
    );

    /// @notice Task submission event
    event TaskSubmitted(
        uint256 indexed taskId,
        address indexed submitter,
        string proof
    );

    /// @notice Task review event
    event TaskReviewed(
        uint256 indexed taskId,
        address indexed reviewer,
        bool approved,
        string feedback
    );

    /// @notice Task completed event
    event TaskCompleted(
        uint256 indexed taskId,
        address indexed assignee,
        uint256 reward
    );

    /// @notice Jury member joined
    event JuryMemberJoined(
        address indexed member,
        uint256 stakedAmount
    );

    /// @notice Jury member left
    event JuryMemberLeft(
        address indexed member,
        uint256 returnedAmount
    );

    /// @notice Dispute initiated
    event DisputeInitiated(
        uint256 indexed taskId,
        address indexed challenger,
        address[3] selectedJury,
        uint256 disputeFee
    );

    /// @notice Jury vote cast
    event JuryVoteCast(
        uint256 indexed taskId,
        address indexed juror,
        uint256 vote
    );

    /// @notice Dispute resolved
    event DisputeResolved(
        uint256 indexed taskId,
        uint256 finalDecision,
        address[3] juryMembers,
        uint256 assigneeReward,
        uint256 publisherRefund
    );

    /// @notice Protocol fee collected
    event ProtocolFeeCollected(
        uint256 indexed taskId,
        address indexed communityAddress,
        uint256 amount
    );

    // ==================== MODIFIERS ====================

    /// @notice Ensures caller is authorized publisher for the community
    modifier onlyCommunityPublisher(address community) {
        require(
            communityPublishers[community][msg.sender] ||
            _isCommunityOwner(community, msg.sender),
            "Not authorized publisher for this community"
        );
        _;
    }

    /// @notice Ensures task exists
    modifier taskExists(uint256 taskId) {
        require(tasks[taskId].publisher != address(0), "Task does not exist");
        _;
    }

    /// @notice Ensures caller is task publisher
    modifier onlyTaskPublisher(uint256 taskId) {
        require(tasks[taskId].publisher == msg.sender, "Not task publisher");
        _;
    }

    /// @notice Ensures caller is task assignee
    modifier onlyTaskAssignee(uint256 taskId) {
        require(tasks[taskId].assignee == msg.sender, "Not task assignee");
        _;
    }

    /// @notice Ensures caller is jury member
    modifier onlyJuryMember() {
        require(juryMembers[msg.sender].isActive, "Not an active jury member");
        _;
    }

    // ==================== CONSTRUCTOR ====================

    constructor(
        address registry,
        address gToken,
        address treasury
    ) Ownable(msg.sender) {
        REGISTRY = registry;
        GTOKEN = gToken;
        TREASURY = treasury;
        _taskIdCounter = 1;
    }

    // ==================== PUBLISHER MANAGEMENT ====================

    /// @notice Authorize publisher for a community
    /// @dev Only community owners or authorized parties can call this
    function authorizePublisher(address community, address publisher) external {
        require(_isAuthorizedForCommunity(community, msg.sender), "Not authorized");
        communityPublishers[community][publisher] = true;
    }

    /// @notice Revoke publisher authorization
    function revokePublisherAuthorization(address community, address publisher) external {
        require(_isAuthorizedForCommunity(community, msg.sender), "Not authorized");
        communityPublishers[community][publisher] = false;
    }

    // ==================== TASK MANAGEMENT ====================

    /// @notice Publish a new task
    /// @param communityAddress Community to associate task with
    /// @param title Task title
    /// @param description Task description
    /// @param reward Reward amount in community xPNTs
    /// @param duration Duration in seconds until deadline
    /// @param taskType Type of task (Exclusive or Open)
    /// @param enableJury Whether to enable jury dispute resolution
    function publishTask(
        address communityAddress,
        string memory title,
        string memory description,
        uint256 reward,
        uint256 duration,
        TaskType taskType,
        bool enableJury
    ) external onlyCommunityPublisher(communityAddress) returns (uint256) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(reward > 0, "Reward must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");

        // Get community xPNTs token from registry
        address xPNTsToken = _getCommunityXPNTs(communityAddress);
        require(xPNTsToken != address(0), "Invalid community xPNTs token");

        uint256 taskId = _taskIdCounter++;
        uint256 deadline = block.timestamp + duration;
        uint256 disputeFee = enableJury ? DISPUTE_FEE_RATE : 0;

        tasks[taskId] = Task({
            id: taskId,
            publisher: msg.sender,
            communityAddress: communityAddress,
            xPNTsToken: xPNTsToken,
            title: title,
            description: description,
            reward: reward,
            deadline: deadline,
            status: TaskStatus.Open,
            taskType: taskType,
            assignee: address(0),
            juryEnabled: enableJury,
            disputeFee: disputeFee,
            createdAt: block.timestamp,
            updatedAt: block.timestamp,
            submissionProof: "",
            reviewResult: "",
            disputeStatus: DisputeStatus.None,
            protocolFeeRate: PROTOCOL_FEE_RATE
        });

        // Update publisher reputation
        _updatePublisherReputation(msg.sender, true);

        // Transfer reward from publisher to this contract
        require(
            IERC20(xPNTsToken).transferFrom(msg.sender, address(this), reward),
            "Reward transfer failed"
        );

        emit TaskPublished(taskId, msg.sender, communityAddress, title, reward, taskType, enableJury);
        return taskId;
    }

    /// @notice Apply for an exclusive task
    function applyForTask(uint256 taskId) external taskExists(taskId) {
        Task storage task = tasks[taskId];

        require(task.status == TaskStatus.Open, "Task is not open for applications");
        require(task.taskType == TaskType.Exclusive, "Task is not exclusive type");
        require(task.assignee == address(0), "Task already assigned");
        require(block.timestamp < task.deadline, "Task has expired");

        task.assignee = msg.sender;
        task.status = TaskStatus.InProgress;
        task.updatedAt = block.timestamp;

        emit TaskApplied(taskId, msg.sender);
    }

    /// @notice Submit task completion proof
    /// @param taskId Task ID
    /// @param proof Proof of completion
    function submitTask(uint256 taskId, string memory proof)
        external
        taskExists(taskId)
        nonReentrant
    {
        Task storage task = tasks[taskId];

        if (task.taskType == TaskType.Exclusive) {
            require(task.assignee == msg.sender, "Not assigned to this task");
        }

        require(task.status == TaskStatus.InProgress, "Task is not in progress");
        require(block.timestamp <= task.deadline, "Task deadline passed");

        task.submissionProof = proof;
        task.status = TaskStatus.InReview;
        task.updatedAt = block.timestamp;

        emit TaskSubmitted(taskId, msg.sender, proof);
    }

    /// @notice Review and approve/reject task submission
    /// @param taskId Task ID
    /// @param approved Whether to approve the submission
    /// @param feedback Review feedback
    function reviewTask(
        uint256 taskId,
        bool approved,
        string memory feedback
    ) external onlyTaskPublisher(taskId) nonReentrant {
        Task storage task = tasks[taskId];

        require(task.status == TaskStatus.InReview, "Task is not in review");

        task.reviewResult = feedback;
        task.updatedAt = block.timestamp;

        if (approved) {
            _completeTask(taskId);
        } else {
            task.status = TaskStatus.InProgress;
        }

        emit TaskReviewed(taskId, msg.sender, approved, feedback);
    }

    // ==================== JURY SYSTEM ====================

    /// @notice Join the jury system by staking GToken
    function joinJury() external {
        require(!juryMembers[msg.sender].isActive, "Already a jury member");

        // Transfer GToken for staking
        require(
            IERC20(GTOKEN).transferFrom(msg.sender, address(this), MIN_JURY_STAKE),
            "Insufficient GToken stake"
        );

        juryMembers[msg.sender] = JuryMember({
            memberAddress: msg.sender,
            stakedAmount: MIN_JURY_STAKE,
            reputation: 5000, // Start with 50% reputation
            casesParticipated: 0,
            casesResolved: 0,
            isActive: true,
            joinedAt: block.timestamp
        });

        activeJuryMembers.push(msg.sender);
        totalJuryMembers++;

        emit JuryMemberJoined(msg.sender, MIN_JURY_STAKE);
    }

    /// @notice Leave the jury system and return stake
    function leaveJury() external onlyJuryMember {
        JuryMember storage member = juryMembers[msg.sender];
        require(member.casesParticipated == 0, "Have active dispute cases");

        // Return staked GToken
        require(
            IERC20(GTOKEN).transfer(msg.sender, member.stakedAmount),
            "Stake return failed"
        );

        // Remove from active members
        _removeFromActiveJury(msg.sender);
        delete juryMembers[msg.sender];
        totalJuryMembers--;

        emit JuryMemberLeft(msg.sender, member.stakedAmount);
    }

    /// @notice Initiate a dispute for a task
    /// @param taskId Task ID to dispute
    /// @param reason Dispute description
    function initiateDispute(uint256 taskId, string memory reason)
        external
        payable
        taskExists(taskId)
    {
        Task storage task = tasks[taskId];

        require(task.juryEnabled, "Jury not enabled for this task");
        require(task.disputeStatus == DisputeStatus.None, "Dispute already initiated");
        require(
            msg.sender == task.assignee || msg.sender == task.publisher,
            "Not authorized to dispute"
        );
        require(task.status == TaskStatus.InReview || task.status == TaskStatus.Completed, "Task not reviewable");

        uint256 requiredFee = (task.reward * DISPUTE_FEE_RATE) / BPS_DENOMINATOR;
        require(msg.value == requiredFee, "Incorrect dispute fee");

        // Select random jury members
        address[3] memory selectedJury = _selectRandomJury(taskId);

        // Create dispute case
        disputes[taskId] = DisputeCase({
            taskId: taskId,
            challenger: msg.sender,
            respondent: msg.sender == task.assignee ? task.publisher : task.assignee,
            selectedJury: selectedJury,
            disputeFee: msg.value * 2, // Both parties pay, so total is 2x
            juryReward: (msg.value * JURY_REWARD_RATE) / BPS_DENOMINATOR,
            description: reason,
            votes: [uint256(0), uint256(0), uint256(0)],
            finalDecision: 0,
            isResolved: false,
            createdAt: block.timestamp,
            resolvedAt: 0
        });

        task.disputeStatus = DisputeStatus.Pending;
        task.status = TaskStatus.Disputed;
        task.updatedAt = block.timestamp;

        emit DisputeInitiated(taskId, msg.sender, selectedJury, msg.value);
    }

    /// @notice Vote on a dispute case
    /// @param taskId Task ID
    /// @param decision Percentage reward for assignee (0-100%)
    function voteOnDispute(uint256 taskId, uint256 decision)
        external
        onlyJuryMember
        taskExists(taskId)
    {
        DisputeCase storage dispute = disputes[taskId];

        require(dispute.isResolved == false, "Dispute already resolved");
        require(decision <= 100, "Decision must be between 0-100");

        // Check if caller is one of the selected jury members
        bool isJuryMember = false;
        for (uint i = 0; i < 3; i++) {
            if (dispute.selectedJury[i] == msg.sender) {
                require(dispute.votes[i] == 0, "Already voted");
                dispute.votes[i] = decision;
                isJuryMember = true;
                break;
            }
        }

        require(isJuryMember, "Not selected for this dispute");

        emit JuryVoteCast(taskId, msg.sender, decision);

        // Check if all jury members have voted
        if (_allJuriesVoted(taskId)) {
            _resolveDispute(taskId);
        }
    }

    // ==================== INTERNAL FUNCTIONS ====================

    /// @notice Complete a task and distribute rewards
    function _completeTask(uint256 taskId) internal {
        Task storage task = tasks[taskId];

        uint256 protocolFee = (task.reward * task.protocolFeeRate) / BPS_DENOMINATOR;
        uint256 actualReward = task.reward - protocolFee;

        // Send protocol fee to treasury
        if (protocolFee > 0) {
            IERC20(task.xPNTsToken).transfer(TREASURY, protocolFee);
            emit ProtocolFeeCollected(taskId, task.communityAddress, protocolFee);
        }

        // Send reward to assignee
        IERC20(task.xPNTsToken).transfer(task.assignee, actualReward);

        task.status = TaskStatus.Completed;
        task.updatedAt = block.timestamp;

        // Update publisher reputation
        _updatePublisherReputation(task.publisher, true);

        emit TaskCompleted(taskId, task.assignee, actualReward);
    }

    /// @notice Resolve a dispute case
    function _resolveDispute(uint256 taskId) internal {
        DisputeCase storage dispute = disputes[taskId];
        Task storage task = tasks[taskId];

        // Calculate average vote
        uint256 totalVotes = 0;
        uint256 voterCount = 0;

        for (uint i = 0; i < 3; i++) {
            if (dispute.votes[i] > 0) {
                totalVotes += dispute.votes[i];
                voterCount++;
            }
        }

        require(voterCount > 0, "No votes recorded");

        uint256 finalDecision = totalVotes / voterCount; // Average percentage
        dispute.finalDecision = finalDecision;
        dispute.isResolved = true;
        dispute.resolvedAt = block.timestamp;

        // Calculate reward distribution
        uint256 assigneeReward = (task.reward * finalDecision) / 100;
        uint256 publisherRefund = task.reward - assigneeReward;

        // Handle protocol fee
        uint256 protocolFee = (task.reward * task.protocolFeeRate) / BPS_DENOMINATOR;
        assigneeReward = assigneeReward > protocolFee ? assigneeReward - protocolFee : 0;
        publisherRefund = publisherRefund > 0 ? publisherRefund : 0;

        // Distribute rewards
        if (assigneeReward > 0) {
            IERC20(task.xPNTsToken).transfer(task.assignee, assigneeReward);
        }

        if (publisherRefund > 0) {
            IERC20(task.xPNTsToken).transfer(task.publisher, publisherRefund);
        }

        // Pay jury rewards
        uint256 jurorReward = dispute.juryReward / 3;
        for (uint i = 0; i < 3; i++) {
            if (dispute.selectedJury[i] != address(0)) {
                IERC20(task.xPNTsToken).transfer(dispute.selectedJury[i], jurorReward);

                // Update juror stats
                JuryMember storage juror = juryMembers[dispute.selectedJury[i]];
                juror.casesResolved++;
                juror.casesParticipated--;
            }
        }

        // Send protocol fee
        if (protocolFee > 0) {
            IERC20(task.xPNTsToken).transfer(TREASURY, protocolFee);
            emit ProtocolFeeCollected(taskId, task.communityAddress, protocolFee);
        }

        // Update task status
        task.disputeStatus = DisputeStatus.Resolved;
        task.status = TaskStatus.Completed;
        task.updatedAt = block.timestamp;

        emit DisputeResolved(taskId, finalDecision, dispute.selectedJury, assigneeReward, publisherRefund);
    }

    /// @notice Select 3 random jury members
    function _selectRandomJury(uint256 taskId) internal view returns (address[3] memory) {
        require(totalJuryMembers >= 3, "Insufficient jury members");

        address[3] memory selected;
        uint256[] memory availableIndices = new uint256[](totalJuryMembers);

        // Create array of available indices
        for (uint256 i = 0; i < totalJuryMembers; i++) {
            availableIndices[i] = i;
        }

        // Fisher-Yates shuffle for first 3 elements
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, taskId)));

        for (uint256 i = 0; i < 3; i++) {
            uint256 randomIndex = (seed + i) % (totalJuryMembers - i);
            uint256 selectedIndex = availableIndices[randomIndex];
            selected[i] = activeJuryMembers[selectedIndex];

            // Move last element to current position
            availableIndices[randomIndex] = availableIndices[totalJuryMembers - i - 1];
        }

        return selected;
    }

    /// @notice Check if all selected jury members have voted
    function _allJuriesVoted(uint256 taskId) internal view returns (bool) {
        DisputeCase storage dispute = disputes[taskId];

        for (uint i = 0; i < 3; i++) {
            if (dispute.selectedJury[i] != address(0) && dispute.votes[i] == 0) {
                return false;
            }
        }

        return true;
    }

    /// @notice Remove address from active jury members
    function _removeFromActiveJury(address member) internal {
        uint256 length = activeJuryMembers.length;

        for (uint256 i = 0; i < length; i++) {
            if (activeJuryMembers[i] == member) {
                // Move last element to current position
                activeJuryMembers[i] = activeJuryMembers[length - 1];
                // Remove last element
                activeJuryMembers.pop();
                break;
            }
        }
    }

    /// @notice Update publisher reputation
    function _updatePublisherReputation(address publisher, bool success) internal {
        PublisherReputation storage rep = publisherReputations[publisher];

        rep.totalTasks++;
        rep.lastActivity = block.timestamp;

        if (rep.totalTasks == 1) {
            // First task, initialize reputation
            rep.isActive = true;
        }

        if (success) {
            rep.completedTasks++;
            rep.successRate = (rep.completedTasks * BPS_DENOMINATOR) / rep.totalTasks;
        }

        // Update activity status
        rep.isActive = (block.timestamp - rep.lastActivity) <= 30 days;
    }

    /// @notice Get community xPNTs token from registry
    function _getCommunityXPNTs(address community) internal view returns (address) {
        // This would interface with the Registry contract
        // For now, return a placeholder
        return address(0); // To be implemented with Registry interface
    }

    /// @notice Check if address is community owner
    function _isCommunityOwner(address community, address account) internal view returns (bool) {
        // This would interface with the Registry contract
        // For now, return false
        return false; // To be implemented with Registry interface
    }

    /// @notice Check if address is authorized for community
    function _isAuthorizedForCommunity(address community, address account) internal view returns (bool) {
        // This would interface with the Registry contract
        // For now, return false
        return false; // To be implemented with Registry interface
    }

    // ==================== VIEW FUNCTIONS ====================

    /// @notice Get task details
    function getTask(uint256 taskId) external view returns (Task memory) {
        return tasks[taskId];
    }

    /// @notice Get dispute case details
    function getDispute(uint256 taskId) external view returns (DisputeCase memory) {
        return disputes[taskId];
    }

    /// @notice Get publisher reputation
    function getPublisherReputation(address publisher) external view returns (PublisherReputation memory) {
        return publisherReputations[publisher];
    }

    /// @notice Get jury member info
    function getJuryMember(address member) external view returns (JuryMember memory) {
        return juryMembers[member];
    }

    /// @notice Calculate reputation score for a publisher
    function getReputationScore(address publisher) external view returns (uint256) {
        PublisherReputation memory rep = publisherReputations[publisher];

        if (rep.totalTasks == 0) return 0;

        // Scoring algorithm based on multiple factors
        uint256 score = 0;

        // Success rate weight: 40%
        score += (rep.successRate * 40) / BPS_DENOMINATOR;

        // Task volume weight: 30% (max 3000 points)
        score += (rep.totalTasks * 100 > 3000) ? 3000 : rep.totalTasks * 100;

        // Activity weight: 20%
        score += rep.isActive ? 2000 : 0;

        // Dispute penalty: 10% (max 1000 points penalty)
        score += (1000 > rep.disputeCount * 100) ? (1000 - rep.disputeCount * 100) : 0;

        return score;
    }

    /// @notice Get active jury members count
    function getActiveJuryCount() external view returns (uint256) {
        return totalJuryMembers;
    }
}
