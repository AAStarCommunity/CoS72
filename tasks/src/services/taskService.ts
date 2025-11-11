// Task Service for managing task-related operations
// This service will integrate with the TaskContract once deployed

import { ethers } from "ethers";

// Task status enum matching the contract
export enum TaskStatus {
  Open = "Open",
  InProgress = "InProgress",
  InReview = "InReview",
  Completed = "Completed",
  Cancelled = "Cancelled",
  Disputed = "Disputed",
}

// Task interface matching the contract struct
export interface Task {
  id: number;
  publisher: string;
  title: string;
  description: string;
  reward: number;
  deadline: number;
  status: TaskStatus;
  assignee: string;
  createdAt: number;
  updatedAt: number;
  submissionProof?: string;
  reviewResult?: string;
}

// Publisher reputation interface
export interface PublisherReputation {
  totalTasks: number;
  completedTasks: number;
  totalRewards: number;
  averageResponseTime: number;
  disputeCount: number;
  successRate: number;
  isActive: boolean;
}

// Task creation parameters
export interface CreateTaskParams {
  title: string;
  description: string;
  reward: number;
  duration: number; // in seconds
}

// Task application parameters
export interface ApplyTaskParams {
  taskId: number;
  applicantMessage?: string;
}

// Task submission parameters
export interface SubmitTaskParams {
  taskId: number;
  proof: string;
}

// Task review parameters
export interface ReviewTaskParams {
  taskId: number;
  approved: boolean;
  feedback?: string;
}

// Mock data for development (will be replaced with contract calls)
const mockTasks: Task[] = [
  {
    id: 1,
    publisher: "0x411BD567E46C0781248dbB6a9211891C032885e5",
    title: "Translate our homepage to Chinese",
    description:
      "Translate the main page content from English to simplified Chinese.",
    reward: 100,
    deadline: Date.now() + 7 * 24 * 60 * 60 * 1000, // 7 days from now
    status: TaskStatus.Open,
    assignee: ethers.ZeroAddress,
    createdAt: Date.now() - 2 * 24 * 60 * 60 * 1000, // 2 days ago
    updatedAt: Date.now() - 2 * 24 * 60 * 60 * 1000,
  },
  {
    id: 2,
    publisher: "0x411BD567E46C0781248dbB6a9211891C032885e5",
    title: "Design a new logo for the Task Square",
    description: "Create a modern and clean logo. Submit as SVG.",
    reward: 250,
    deadline: Date.now() + 14 * 24 * 60 * 60 * 1000, // 14 days from now
    status: TaskStatus.Open,
    assignee: ethers.ZeroAddress,
    createdAt: Date.now() - 1 * 24 * 60 * 60 * 1000, // 1 day ago
    updatedAt: Date.now() - 1 * 24 * 60 * 60 * 1000,
  },
  {
    id: 3,
    publisher: "0x411BD567E46C0781248dbB6a9211891C032885e5",
    title: "Write a tutorial on how to use the platform",
    description: "A step-by-step guide for new users with screenshots.",
    reward: 150,
    deadline: Date.now() + 10 * 24 * 60 * 60 * 1000, // 10 days from now
    status: TaskStatus.InProgress,
    assignee: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
    createdAt: Date.now() - 3 * 24 * 60 * 60 * 1000, // 3 days ago
    updatedAt: Date.now() - 12 * 60 * 60 * 1000, // 12 hours ago
  },
];

const mockReputations: Record<string, PublisherReputation> = {
  "0x411BD567E46C0781248dbB6a9211891C032885e5": {
    totalTasks: 15,
    completedTasks: 12,
    totalRewards: 3500,
    averageResponseTime: 86400, // 1 day in seconds
    disputeCount: 1,
    successRate: 8000, // 80% in basis points
    isActive: true,
  },
};

// Task Service class
export class TaskService {
  private userAddress: string | null = null;

  // Initialize the service with user's signer
  async initialize(signer?: ethers.Signer) {
    try {
      this.userAddress = (await signer?.getAddress()) || null;

      // TODO: Initialize task contract when deployed
      // this.taskContract = new ethers.Contract(TASK_CONTRACT_ADDRESS, TASK_CONTRACT_ABI, signer);

      console.log("TaskService initialized for address:", this.userAddress);
    } catch (error) {
      console.error("Failed to initialize TaskService:", error);
      throw error;
    }
  }

  // Get all tasks (filtered by status optionally)
  async getTasks(statusFilter?: TaskStatus): Promise<Task[]> {
    try {
      // TODO: Replace with contract call
      // const tasks = await this.taskContract.getTasks(statusFilter);

      let filteredTasks = mockTasks;
      if (statusFilter) {
        filteredTasks = mockTasks.filter(
          (task) => task.status === statusFilter,
        );
      }

      return filteredTasks;
    } catch (error) {
      console.error("Failed to get tasks:", error);
      throw error;
    }
  }

  // Get a specific task by ID
  async getTask(taskId: number): Promise<Task | null> {
    try {
      // TODO: Replace with contract call
      // const task = await this.taskContract.getTask(taskId);

      return mockTasks.find((task) => task.id === taskId) || null;
    } catch (error) {
      console.error("Failed to get task:", error);
      throw error;
    }
  }

  // Get tasks published by a specific address
  async getTasksByPublisher(publisher: string): Promise<Task[]> {
    try {
      // TODO: Replace with contract call
      // const tasks = await this.taskContract.getTasksByPublisher(publisher);

      return mockTasks.filter(
        (task) => task.publisher.toLowerCase() === publisher.toLowerCase(),
      );
    } catch (error) {
      console.error("Failed to get tasks by publisher:", error);
      throw error;
    }
  }

  // Get tasks assigned to a specific address
  async getTasksByAssignee(assignee: string): Promise<Task[]> {
    try {
      // TODO: Replace with contract call
      // const tasks = await this.taskContract.getTasksByAssignee(assignee);

      return mockTasks.filter(
        (task) => task.assignee.toLowerCase() === assignee.toLowerCase(),
      );
    } catch (error) {
      console.error("Failed to get tasks by assignee:", error);
      throw error;
    }
  }

  // Publish a new task
  async publishTask(params: CreateTaskParams): Promise<number> {
    try {
      if (!this.userAddress) {
        throw new Error("User not connected");
      }

      // TODO: Replace with contract call
      // const tx = await this.taskContract.publishTask(
      //   params.title,
      //   params.description,
      //   params.reward,
      //   params.duration
      // );
      // const receipt = await tx.wait();
      // return receipt.events?.find(e => e.event === 'TaskPublished')?.args?.taskId;

      // Mock implementation
      const newTaskId = Math.max(...mockTasks.map((t) => t.id)) + 1;
      const newTask: Task = {
        id: newTaskId,
        publisher: this.userAddress,
        title: params.title,
        description: params.description,
        reward: params.reward,
        deadline: Date.now() + params.duration * 1000,
        status: TaskStatus.Open,
        assignee: ethers.ZeroAddress,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      };

      mockTasks.unshift(newTask);
      console.log("Mock task published:", newTask);

      return newTaskId;
    } catch (error) {
      console.error("Failed to publish task:", error);
      throw error;
    }
  }

  // Apply for a task
  async applyForTask(params: ApplyTaskParams): Promise<void> {
    try {
      if (!this.userAddress) {
        throw new Error("User not connected");
      }

      // TODO: Replace with contract call
      // const tx = await this.taskContract.applyForTask(params.taskId);
      // await tx.wait();

      // Mock implementation
      const task = mockTasks.find((t) => t.id === params.taskId);
      if (!task) {
        throw new Error("Task not found");
      }
      if (task.status !== TaskStatus.Open) {
        throw new Error("Task is not open for applications");
      }

      task.status = TaskStatus.InProgress;
      task.assignee = this.userAddress;
      task.updatedAt = Date.now();

      console.log(
        "Mock task application:",
        params.taskId,
        "by",
        this.userAddress,
      );
    } catch (error) {
      console.error("Failed to apply for task:", error);
      throw error;
    }
  }

  // Submit a completed task
  async submitTask(params: SubmitTaskParams): Promise<void> {
    try {
      if (!this.userAddress) {
        throw new Error("User not connected");
      }

      // TODO: Replace with contract call
      // const tx = await this.taskContract.submitTask(params.taskId, params.proof);
      // await tx.wait();

      // Mock implementation
      const task = mockTasks.find((t) => t.id === params.taskId);
      if (!task) {
        throw new Error("Task not found");
      }
      if (task.assignee.toLowerCase() !== this.userAddress.toLowerCase()) {
        throw new Error("Not assigned to this task");
      }
      if (task.status !== TaskStatus.InProgress) {
        throw new Error("Task is not in progress");
      }

      task.status = TaskStatus.InReview;
      task.submissionProof = params.proof;
      task.updatedAt = Date.now();

      console.log(
        "Mock task submission:",
        params.taskId,
        "by",
        this.userAddress,
      );
    } catch (error) {
      console.error("Failed to submit task:", error);
      throw error;
    }
  }

  // Review a submitted task
  async reviewTask(params: ReviewTaskParams): Promise<void> {
    try {
      if (!this.userAddress) {
        throw new Error("User not connected");
      }

      // TODO: Replace with contract call
      // const tx = await this.taskContract.reviewTask(
      //   params.taskId,
      //   params.approved,
      //   params.feedback
      // );
      // await tx.wait();

      // Mock implementation
      const task = mockTasks.find((t) => t.id === params.taskId);
      if (!task) {
        throw new Error("Task not found");
      }
      if (task.publisher.toLowerCase() !== this.userAddress.toLowerCase()) {
        throw new Error("Not the task publisher");
      }
      if (task.status !== TaskStatus.InReview) {
        throw new Error("Task is not in review");
      }

      task.status = params.approved
        ? TaskStatus.Completed
        : TaskStatus.InProgress;
      task.reviewResult = params.feedback;
      task.updatedAt = Date.now();

      console.log(
        "Mock task review:",
        params.taskId,
        "approved:",
        params.approved,
      );
    } catch (error) {
      console.error("Failed to review task:", error);
      throw error;
    }
  }

  // Get publisher reputation
  async getPublisherReputation(
    publisher: string,
  ): Promise<PublisherReputation> {
    try {
      // TODO: Replace with contract call
      // const reputation = await this.taskContract.getPublisherReputation(publisher);

      // Mock implementation
      return (
        mockReputations[publisher.toLowerCase()] || {
          totalTasks: 0,
          completedTasks: 0,
          totalRewards: 0,
          averageResponseTime: 0,
          disputeCount: 0,
          successRate: 0,
          isActive: false,
        }
      );
    } catch (error) {
      console.error("Failed to get publisher reputation:", error);
      throw error;
    }
  }

  // Get reputation score
  async getReputationScore(publisher: string): Promise<number> {
    try {
      // TODO: Replace with contract call
      // const score = await this.taskContract.getReputationScore(publisher);

      // Mock implementation
      const reputation = await this.getPublisherReputation(publisher);

      // Mock scoring calculation (matches contract design)
      let score = 0;
      score += (reputation.successRate * 40) / 100; // 40% weight
      score += Math.min(reputation.totalTasks * 100, 3000); // 30% weight, max 3000
      score += reputation.isActive ? 2000 : 0; // 20% weight
      score += Math.max(0, 1000 - reputation.disputeCount * 100); // 10% weight

      return Math.min(score, 10000); // Max score is 10000
    } catch (error) {
      console.error("Failed to get reputation score:", error);
      throw error;
    }
  }

  // Listen to task events (for real-time updates)
  onTaskPublished(_callback: (task: Task) => void) {
    // TODO: Implement event listening when contract is deployed
    // this.taskContract.on("TaskPublished", callback);
    console.log("Event listening not yet implemented");
  }

  onTaskApplied(_callback: (taskId: number, applicant: string) => void) {
    // TODO: Implement event listening when contract is deployed
    // this.taskContract.on("TaskApplied", callback);
    console.log("Event listening not yet implemented");
  }

  onTaskSubmitted(_callback: (taskId: number, proof: string) => void) {
    // TODO: Implement event listening when contract is deployed
    // this.taskContract.on("TaskSubmitted", callback);
    console.log("Event listening not yet implemented");
  }

  onTaskReviewed(
    _callback: (taskId: number, approved: boolean, feedback: string) => void,
  ) {
    // TODO: Implement event listening when contract is deployed
    // this.taskContract.on("TaskReviewed", callback);
    console.log("Event listening not yet implemented");
  }

  // Disconnect the service
  disconnect() {
    this.userAddress = null;
    console.log("TaskService disconnected");
  }
}

// Export singleton instance
export const taskService = new TaskService();
