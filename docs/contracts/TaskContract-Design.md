# COS72 任务广场智能合约设计文档

## 概述

COS72任务广场是一个去中心化的社区任务市场，支持任务发布、申请、审核、完成和奖励发放的全生命周期管理。该合约系统与现有的Registry（社区注册）和xPNTs（社区积分）系统深度集成。

## 核心设计原则

1. **可升级性**: 使用Factory + Proxy模式实现合约升级
2. **模块化**: 任务管理、声誉系统、协议收入分离
3. **安全性**: 所有权限操作都有严格的访问控制
4. **透明度**: 所有任务和奖励记录公开可查
5. **效率**: 优化Gas消耗，支持批量操作

## 合约架构

### 1. TaskFactory (工厂合约)
```solidity
contract TaskFactory {
    // 部署新的任务合约实例
    function deployTaskContract(string memory communityName) external returns (address);
    
    // 获取社区的任务合约地址
    function getTaskContract(string memory communityName) external view returns (address);
    
    // 升级任务合约逻辑
    function upgradeTaskContract(string memory communityName, address newImplementation) external;
}
```

### 2. TaskContract (核心任务合约)
```solidity
contract TaskContract {
    // 任务状态枚举
    enum TaskStatus { Open, InProgress, InReview, Completed, Cancelled, Disputed }
    
    // 任务类型枚举
    enum TaskType { Exclusive, Open } // Exclusive: 单人申请, Open: 任何人可完成
    
    // 争议状态
    enum DisputeStatus { None, Pending, Resolved }
    
    // 任务结构
    struct Task {
        uint256 id;
        address publisher;          // 发布者地址
        address communityAddress;    // 社区地址
        address xPNTsToken;        // 社区积分代币地址
        string title;               // 任务标题
        string description;         // 任务描述
        uint256 reward;             // 奖励金额(xPNTs)
        uint256 deadline;           // 截止时间
        TaskStatus status;          // 任务状态
        TaskType taskType;          // 任务类型
        address assignee;           // 执行者地址(Exclusive类型)
        bool juryEnabled;           // 是否启用Jury争议解决
        uint256 disputeFee;         // 争议费用(5% = 500 basis points)
        uint256 createdAt;          // 创建时间
        uint256 updatedAt;          // 更新时间
        string submissionProof;     // 提交证明
        string reviewResult;        // 审核结果
        DisputeStatus disputeStatus; // 争议状态
    };
    }
    
    // 发布者声誉结构
    struct PublisherReputation {
        uint256 totalTasks;         // 发布任务总数
        uint256 completedTasks;     // 已完成任务数
        uint256 totalRewards;       // 总奖励金额
        uint256 averageResponseTime;// 平均响应时间
        uint256 disputeCount;       // 争议次数
        uint256 successRate;        // 成功率 (basis points, 10000 = 100%)
        bool isActive;              // 是否活跃
    }
}
```

### 3. JurySystem (争议解决系统)
```solidity
contract JurySystem {
    // Jury成员结构
    struct JuryMember {
        address memberAddress;
        uint256 stakedAmount;     // 质押的GToken数量(最低10)
        uint256 reputation;        // 声誉评分
        uint256 casesParticipated;  // 参与案件数
        uint256 casesResolved;     // 解决案件数
        bool isActive;            // 是否活跃
        uint256 joinedAt;         // 加入时间
    }
    
    // 争议案件结构
    struct DisputeCase {
        uint256 taskId;
        address challenger;       // 争议发起方
        address respondent;       // 争议响应方
        address[3] selectedJury; // 随机选取的3位Jury
        uint256 disputeFee;      // 争议费用总额(双方各5% = 10%)
        uint256 juryReward;      // Jury报酬
        string description;       // 争议描述
        uint256[3] votes;       // 3位Jury的投票结果(0-100%)
        uint256 finalDecision;    // 最终决定(0-100%)
        bool isResolved;         // 是否已解决
        uint256 createdAt;       // 创建时间
        uint256 resolvedAt;      // 解决时间
    }
    
    // Jury质押最低要求
    uint256 public constant MIN_JURY_STAKE = 10 ether; // 10 GToken
    
    // 争议费用率
    uint256 public constant DISPUTE_FEE_RATE = 500; // 5% (500/10000)
    uint256 public constant JURY_REWARD_RATE = 200; // Jury报酬率(2%)
}
```

### 4. ProtocolTreasury (协议金库)
```solidity
contract ProtocolTreasury {
    // 协议收入分配
    uint256 public constant PROTOCOL_FEE_RATE = 100; // 1% (100/10000)
    
    // 收入分配比例
    uint256 public constant COMMUNITY_REVENUE_SHARE = 7000; // 70%
    uint256 public constant PROTOCOL_REVENUE_SHARE = 3000;   // 30%
    
    // 分配收入
    function distributeRevenue(
        address community,
        uint256 amount
    ) external payable;
    
    // 处理争议费用
    function handleDisputeFees(
        uint256 taskId,
        uint256 totalFee,
        address[3] jury
    ) external payable returns (uint256 juryReward);
}
```

## 核心功能

### 1. 任务管理流程

#### 发布任务
```solidity
function publishTask(
    string calldata title,
    string calldata description,
    uint256 reward,
    uint256 duration,
    TaskType taskType,           // 任务类型
    bool enableJury             // 是否启用争议解决
) external returns (uint256 taskId);
```

#### 申请任务(Exclusive类型)
```solidity
function applyForTask(uint256 taskId) external;
```

#### 开放任务提交(Open类型)
```solidity
function submitOpenTask(
    uint256 taskId, 
    address submitter,
    string calldata proof
) external;
```

#### 申请任务
```solidity
function applyForTask(uint256 taskId) external;
```

#### 指派任务
```solidity
function assignTask(uint256 taskId, address assignee) external;
```

#### 提交任务
```solidity
function submitTask(uint256 taskId, string calldata proof) external;
```

#### 审核任务
```solidity
function reviewTask(
    uint256 taskId,
    bool approved,
    string calldata feedback
) external;
```

### 2. 积分自动发放机制

#### 奖励发放
```solidity
function releaseReward(uint256 taskId) internal {
    Task storage task = tasks[taskId];
    
    // 计算协议费用
    uint256 protocolFee = (task.reward * PROTOCOL_FEE_RATE) / 10000;
    uint256 actualReward = task.reward - protocolFee;
    
    // 将协议费用发送到金库
    require(
        IERC20(xPNTsToken).transfer(task.assignee, actualReward),
        "Transfer to assignee failed"
    );
    
    // 发送协议费用到金库
    require(
        IERC20(xPNTsToken).transfer(protocolTreasury, protocolFee),
        "Transfer to treasury failed"
    );
    
    // 更新协议收入统计
    protocolTreasury.distributeRevenue(task.publisher, protocolFee);
}
```

### 3. 声誉系统

#### 更新发布者声誉
```solidity
function updatePublisherReputation(address publisher, bool success) internal {
    PublisherReputation storage rep = publisherReputations[publisher];
    
    rep.totalTasks++;
    if (success) {
        rep.completedTasks++;
        // 更新成功率 (basis points)
        rep.successRate = (rep.completedTasks * 10000) / rep.totalTasks;
    }
    
    rep.isActive = (block.timestamp - lastActivity[publisher]) <= 30 days;
}
```

#### 获取声誉评分
```solidity
function getReputationScore(address publisher) external view returns (uint256 score) {
    PublisherReputation storage rep = publisherReputations[publisher];
    
    // 综合评分计算
    // 成功率权重: 40%
    // 任务数量权重: 30% 
    // 活跃度权重: 20%
    // 争议率权重: 10%
    
    score = (rep.successRate * 40) / 100;
    score += min(rep.totalTasks * 100, 3000);
    score += rep.isActive ? 2000 : 0;
    score += max(0, 1000 - (rep.disputeCount * 100));
}
```

### 4. 协议收入抽成机制

#### 自动收入分配
```solidity
event ProtocolRevenueDistributed(
    address indexed community,
    uint256 totalAmount,
    uint256 communityShare,
    uint256 protocolShare,
    uint256 timestamp
);

function distributeRevenue(
    address community,
    uint256 amount
) external payable onlyTaskContract {
    uint256 communityShare = (amount * COMMUNITY_REVENUE_SHARE) / 10000;
    uint256 protocolShare = (amount * PROTOCOL_REVENUE_SHARE) / 10000;
    
    // 社区收入部分转入社区金库
    IERC20(xPNTsToken).transfer(getCommunityTreasury(community), communityShare);
    
    // 协议收入部分转入协议金库
    IERC20(xPNTsToken).transfer(protocolTreasury, protocolShare);
    
    emit ProtocolRevenueDistributed(community, amount, communityShare, protocolShare, block.timestamp);
}
```

### 5. 争议处理机制

#### 发起争议
#### 争议处理机制
```solidity
// 发起争议(需要支付5%争议费用)
function initiateDispute(uint256 taskId, string calldata reason) external payable {
    require(tasks[taskId].juryEnabled, "Jury not enabled for this task");
    require(msg.sender == tasks[taskId].assignee || msg.sender == tasks[taskId].publisher, "Not authorized");
    require(msg.value == (tasks[taskId].reward * DISPUTE_FEE_RATE) / 10000, "Incorrect dispute fee");
    
    // 选择随机Jury成员
    address[3] selectedJury = selectRandomJury();
    
    // 创建争议案件
    disputes[taskId] = DisputeCase({
        taskId: taskId,
        challenger: msg.sender,
        respondent: msg.sender == tasks[taskId].assignee ? tasks[taskId].publisher : tasks[taskId].assignee,
        selectedJury: selectedJury,
        disputeFee: msg.value,
        juryReward: (msg.value * JURY_REWARD_RATE) / 10000,
        description: reason,
        finalDecision: 0,
        isResolved: false,
        createdAt: block.timestamp
    });
    
    tasks[taskId].disputeStatus = DisputeStatus.Pending;
    emit DisputeInitiated(taskId, msg.sender, selectedJury);
}

// Jury投票
function voteOnDispute(uint256 taskId, uint256 decisionPercentage) external {
    require(isJuryMember(msg.sender), "Not a jury member");
    require(disputes[taskId].isResolved == false, "Dispute already resolved");
    
    // 记录投票
    for (uint i = 0; i < 3; i++) {
        if (disputes[taskId].selectedJury[i] == msg.sender) {
            disputes[taskId].votes[i] = decisionPercentage;
            break;
        }
    }
    
    // 检查是否所有Jury都已投票
    if (allJuriesVoted(taskId)) {
        resolveDispute(taskId);
    }
}
```

#### 自动争议解决
```solidity
function resolveDispute(uint256 taskId) internal {
    DisputeCase storage dispute = disputes[taskId];
    
    // 计算平均投票结果
    uint256 totalVotes = 0;
    uint256 voterCount = 0;
    for (uint i = 0; i < 3; i++) {
        if (dispute.votes[i] > 0) {
            totalVotes += dispute.votes[i];
            voterCount++;
        }
    }
    
    uint256 finalDecision = totalVotes / voterCount; // 0-100%
    dispute.finalDecision = finalDecision;
    dispute.isResolved = true;
    dispute.resolvedAt = block.timestamp;
    
    // 根据投票结果分配奖励
    Task storage task = tasks[taskId];
    uint256 assigneeShare = (task.reward * finalDecision) / 100;
    uint256 publisherShare = task.reward - assigneeShare;
    
    // 分配奖励给执行者
    if (assigneeShare > 0) {
        require(
            IERC20(task.xPNTsToken).transfer(task.assignee, assigneeShare),
            "Transfer to assignee failed"
        );
    }
    
    // 退还剩余给发布者
    if (publisherShare > 0) {
        require(
            IERC20(task.xPNTsToken).transfer(task.publisher, publisherShare),
            "Transfer to publisher failed"
        );
    }
    
    // 支付Jury报酬
    for (uint i = 0; i < 3; i++) {
        if (dispute.selectedJury[i] != address(0)) {
            uint256 jurorReward = dispute.juryReward / 3;
            require(
                IERC20(task.xPNTsToken).transfer(dispute.selectedJury[i], jurorReward),
                "Jury reward transfer failed"
            );
        }
    }
    
    // 更新Jury统计
    updateJuryStats(dispute.selectedJury, true);
    
    task.status = TaskStatus.Completed;
    task.disputeStatus = DisputeStatus.Resolved;
    task.updatedAt = block.timestamp;
    
    emit DisputeResolved(taskId, finalDecision, dispute.selectedJury);
}
```

#### Jury系统管理
```solidity
// 加入Jury(需要质押10 GToken)
function joinJury() external {
    require(!isJuryMember(msg.sender), "Already a jury member");
    
    // 转移GToken到Jury合约进行质押
    require(
        IERC20(gToken).transferFrom(msg.sender, address(this), MIN_JURY_STAKE),
        "Insufficient GToken stake"
    );
    
    juryMembers[msg.sender] = JuryMember({
        memberAddress: msg.sender,
        stakedAmount: MIN_JURY_STAKE,
        reputation: 5000, // 初始声誉50%
        casesParticipated: 0,
        casesResolved: 0,
        isActive: true,
        joinedAt: block.timestamp
    });
    
    totalJuryMembers++;
    emit JuryMemberJoined(msg.sender, MIN_JURY_STAKE);
}

// 退出Jury
function leaveJury() external {
    require(isJuryMember(msg.sender), "Not a jury member");
    require(juryMembers[msg.sender].casesParticipated == 0, "Have active cases");
    
    JuryMember storage member = juryMembers[msg.sender];
    
    // 退还质押的GToken
    require(
        IERC20(gToken).transfer(msg.sender, member.stakedAmount),
        "Stake return failed"
    );
    
    delete juryMembers[msg.sender];
    totalJuryMembers--;
    
    emit JuryMemberLeft(msg.sender, member.stakedAmount);
}
```

## 升级机制

### Factory代理模式
```solidity
contract TaskProxy {
    address public implementation;
    address public admin;
    
    fallback() external payable {
        delegatecall(implementation);
    }
    
    function upgrade(address newImplementation) external onlyAdmin {
        implementation = newImplementation;
    }
}
```

## 安全考虑

### 1. 访问控制
- 只有注册社区可以部署任务合约
- 只有任务发布者可以审核任务
- 只有授权地址可以解决争议

### 2. 重入保护
- 所有外部调用使用ReentrancyGuard
- 积分转账在状态更新后执行

### 3. 权限检查
- 检查任务状态转换的合法性
- 验证调用者的权限
- 防止重复操作

### 4. 经济安全
- 防止发布者恶意拒绝任务完成
- 防止执行者虚假提交
- 通过声誉机制约束行为

## Gas优化策略

### 1. 存储优化
- 使用packed structs减少存储槽
- 及时清理过期数据
- 批量操作减少交易次数

### 2. 计算优化
- 使用view函数进行复杂计算
- 缓存频繁查询的数据
- 避免循环中的复杂操作

### 3. 事件优化
- 精简事件参数
- 使用索引参数提高查询效率
- 批量事件减少Gas消耗

### 集成点
### 1. Registry合约
- 验证社区是否已注册
- 获取社区的xPNTs代币地址  
- 检查社区的stake状态
- 验证发布者是社区所有者或多签成员
```

<old_text line=320>
### Phase 1: 核心功能
- TaskFactory部署
- 基础TaskContract实现
- 协议收入机制
```

### 2. xPNTs合约
- 自动mint/burn积分
- 支持permit签名机制
- 批量转账支持

### 3. GToken Staking
- 声誉系统与stake关联
- 高声誉可降低stake要求
- 违规时slash相关stake

## 测试策略

### 1. 单元测试
- 每个函数的输入输出测试
- 边界条件测试
- 异常情况处理

### 2. 集成测试
- 完整任务流程测试
- 与其他合约的交互测试
- 升级流程测试

### 3. 压力测试
- 大量并发任务处理
- Gas消耗优化验证
- 网络拥堵下的表现

## 部署计划

### Phase 1: 核心功能
- TaskFactory部署
- 基础TaskContract实现
- 协议收入机制

### Phase 2: 高级功能  
- 声誉系统完整实现
- 争议处理机制完整实现(Jury随机选择和投票)
- 升级机制完善
- GToken质押集成
```

### Phase 3: 优化扩展
- Gas优化
- 批量操作
- 跨社区任务支持

---

*此设计文档将根据实际开发过程中的发现持续更新和完善*