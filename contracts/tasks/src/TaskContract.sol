// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title COS72 Task Contract
 * @notice Simplified task management contract for individual compilation
 * @dev Focused on core task lifecycle with basic dispute resolution
 */
contract TaskContract is Ownable, ReentrancyGuard {

    // ==================== ENUMS ====================

    enum TaskStatus {
        Open,        // Task is open for applications
        InProgress,  // Task is being worked on
        InReview,    // Task submission is under review
        Completed,   // Task is completed and rewards paid
        Cancelled,   // Task was cancelled
        Disputed     // Task is under dispute resolution
    }

    enum TaskType {
        Exclusive,    // Only assigned person can complete
        Open         // Anyone can submit and claim reward
    }

    enum DisputeStatus {
        None,        // No dispute
        Pending,     // Dispute is active
        Resolved      // Dispute has been resolved
    }

    // ==================== STRUCTS ====================

    struct Task {
        uint256 id;
        address publisher;
        address communityAddress;
        address xPNTsToken;
        string title;
        string description;
        uint256 reward;
        uint256 deadline;
        TaskStatus status;
        TaskType taskType;
        address assignee;
        bool juryEnabled;
        uint256 createdAt;
        uint256 updatedAt;
        string submissionProof;
        string reviewResult;
        DisputeStatus disputeStatus;
    }

    struct JuryMember {
        address memberAddress;
        uint256 stakedAmount;
        uint256 reputation;
        uint256 casesParticipated;
        uint256 casesResolved;
        bool isActive;
        uint256 joinedAt;
    }

    struct DisputeCase {
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

    // ==================== CONSTANTS ====================

    uint256 public constant MIN_JURY_STAKE = 10 ether;
    uint256 public constant DISPUTE_FEE_RATE = 500; // 5% (500/10000)
    uint256 public constant PROTOCOL_FEE_RATE = 100; // 1% (100/10000)
    uint256 private constant BPS_DENOMINATOR = 10000;

    // ==================== STATE VARIABLES ====================

    address public immutable REGISTRY;
    address public immutable GTOKEN;
    address public immutable TREASURY;

    uint256 private _taskIdCounter;
    uint256 public totalJuryMembers;

    mapping(uint256 => Task) public tasks;
    mapping(uint256 => DisputeCase) public disputes;
    mapping(address => JuryMember) public juryMembers;
    address[] public activeJuryMembers;
    mapping(address => mapping(address => bool)) public communityPublishers;

    // ==================== EVENTS ====================

    event TaskPublished(
        uint256 indexed taskId,
        address indexed publisher,
        address indexed communityAddress,
        string title,
        uint256 reward,
        TaskType taskType,
        bool juryEnabled
    );

    event TaskApplied(
        uint256 indexed taskId,
        address indexed applicant
    );

    event TaskSubmitted(
        uint256 indexed taskId,
        address indexed submitter,
        string proof
    );

    event TaskReviewed(
        uint256 indexed taskId,
        address indexed reviewer,
        bool approved,
        string feedback
    );

    event TaskCompleted(
        uint256 indexed taskId,
        address indexed assignee,
        uint256 reward
    );

    event JuryMemberJoined(
        address indexed member,
        uint256 stakedAmount
    );

    event DisputeInitiated(
        uint256 indexed taskId,
        address indexed challenger,
        address[3] selectedJury,
        uint256 disputeFee
    );

    event DisputeResolved(
        uint256 indexed taskId,
        uint256 finalDecision,
        address[3] juryMembers,
        uint256 assigneeReward,
        uint256 publisherRefund
    );

    // ==================== MODIFIERS ====================

    modifier onlyCommunityPublisher(address community) {
        require(
            communityPublishers[community][msg.sender] || _isCommunityOwner(community, msg.sender),
            "Not authorized publisher for this community"
        );
        _;
    }

    modifier taskExists(uint256 taskId) {
        require(tasks[taskId].publisher != address(0), "Task does not exist");
        _;
    }

    modifier onlyTaskPublisher(uint256 taskId) {
        require(tasks[taskId].publisher == msg.sender, "Not task publisher");
        _;
    }

    modifier onlyTaskAssignee(uint256 taskId) {
        require(tasks[taskId].assignee == msg.sender, "Not task assignee");
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

    function authorizePublisher(address community, address publisher) external {
        require(_isAuthorizedForCommunity(community, msg.sender), "Not authorized");
        communityPublishers[community][publisher] = true;
    }

    // ==================== TASK MANAGEMENT ====================

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

        address xPNTsToken = _getCommunityXPNTs(communityAddress);
        require(xPNTsToken != address(0), "Invalid community xPNTs token");

        uint256 taskId = _taskIdCounter++;
        uint256 deadline = block.timestamp + duration;

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
            createdAt: block.timestamp,
            updatedAt: block.timestamp,
            submissionProof: "",
            reviewResult: "",
            disputeStatus: DisputeStatus.None
        });

        // Transfer reward from publisher to this contract
        require(
            IERC20(xPNTsToken).transferFrom(msg.sender, address(this), reward),
            "Reward transfer failed"
        );

        emit TaskPublished(taskId, msg.sender, communityAddress, title, reward, taskType, enableJury);
        return taskId;
    }

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

    function joinJury() external {
        require(!juryMembers[msg.sender].isActive, "Already a jury member");

        require(
            IERC20(GTOKEN).transferFrom(msg.sender, address(this), MIN_JURY_STAKE),
            "Insufficient GToken stake"
        );

        juryMembers[msg.sender] = JuryMember({
            memberAddress: msg.sender,
            stakedAmount: MIN_JURY_STAKE,
            reputation: 5000,
            casesParticipated: 0,
            casesResolved: 0,
            isActive: true,
            joinedAt: block.timestamp
        });

        activeJuryMembers.push(msg.sender);
        totalJuryMembers++;

        emit JuryMemberJoined(msg.sender, MIN_JURY_STAKE);
    }

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

        uint256 requiredFee = (task.reward * DISPUTE_FEE_RATE) / BPS_DENOMINATOR;
        require(msg.value == requiredFee, "Incorrect dispute fee");

        address[3] memory selectedJury = _selectRandomJury(taskId);

        disputes[taskId] = DisputeCase({
            taskId: taskId,
            challenger: msg.sender,
            respondent: msg.sender == task.assignee ? task.publisher : task.assignee,
            selectedJury: selectedJury,
            disputeFee: msg.value * 2,
            juryReward: (msg.value * 2) / 3,
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

    // ==================== INTERNAL FUNCTIONS ====================

    function _completeTask(uint256 taskId) internal {
        Task storage task = tasks[taskId];

        uint256 protocolFee = (task.reward * PROTOCOL_FEE_RATE) / BPS_DENOMINATOR;
        uint256 actualReward = task.reward - protocolFee;

        if (protocolFee > 0) {
            IERC20(task.xPNTsToken).transfer(TREASURY, protocolFee);
        }

        IERC20(task.xPNTsToken).transfer(task.assignee, actualReward);

        task.status = TaskStatus.Completed;
        task.updatedAt = block.timestamp;

        emit TaskCompleted(taskId, task.assignee, actualReward);
    }

    function _selectRandomJury(uint256 taskId) internal view returns (address[3] memory) {
        require(totalJuryMembers >= 3, "Insufficient jury members");

        address[3] memory selected;
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, taskId)));

        for (uint256 i = 0; i < 3; i++) {
            uint256 randomIndex = (seed + i) % totalJuryMembers;
            selected[i] = activeJuryMembers[randomIndex];
        }

        return selected;
    }

    function _getCommunityXPNTs(address community) internal pure returns (address) {
        // Placeholder - will integrate with Registry
        return address(0x123); // TODO: Implement Registry integration
    }

    function _isCommunityOwner(address community, address account) internal pure returns (bool) {
        // Placeholder - will integrate with Registry
        return false; // TODO: Implement Registry integration
    }

    function _isAuthorizedForCommunity(address community, address account) internal pure returns (bool) {
        // Placeholder - will integrate with Registry
        return false; // TODO: Implement Registry integration
    }

    // ==================== VIEW FUNCTIONS ====================

    function getTask(uint256 taskId) external view returns (Task memory) {
        return tasks[taskId];
    }

    function getDispute(uint256 taskId) external view returns (DisputeCase memory) {
        return disputes[taskId];
    }

    function getActiveJuryCount() external view returns (uint256) {
        return totalJuryMembers;
    }
}
