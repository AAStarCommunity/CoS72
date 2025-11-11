import { useState, useMemo, useEffect } from "react";
import { ethers } from "ethers";
import "./App.css";

// Import from our new separated files using shared-config
import { APNTS_CONTRACT_ADDRESS, APNTS_ABI } from "./contracts/aPNTs";
import { ownerSigner, jsonRpcProvider } from "./services/provider";
import {
  taskService,
  Task,
  TaskStatus,
  CreateTaskParams,
} from "./services/taskService";
import { isRegisteredCommunity } from "./contracts/registry/registry";

// Type declaration for window.ethereum
declare global {
  interface Window {
    ethereum?: any;
  }
}

// --- COMPONENTS ---

const TaskCard = ({
  task,
  onApply,
}: {
  task: Task;
  onApply: (taskId: number) => void;
}) => {
  const isExpired = task.deadline < Date.now();
  const canApply = task.status === TaskStatus.Open && !isExpired;

  return (
    <div className="task-card">
      <h3>{task.title}</h3>
      <p>{task.description}</p>
      <div className="task-meta">
        <span className="points">{task.reward} xPNTs</span>
        <span
          className={`status status-${task.status.toLowerCase().replace(" ", "-")}`}
        >
          {task.status}
        </span>
        <span className="deadline">
          {isExpired
            ? "Expired"
            : `Expires: ${new Date(task.deadline).toLocaleDateString()}`}
        </span>
      </div>
      {canApply && (
        <button className="apply-button" onClick={() => onApply(task.id)}>
          Apply for Task
        </button>
      )}
    </div>
  );
};

const PublishTaskForm = ({
  onPublish,
  isPublishing,
}: {
  onPublish: (newTask: CreateTaskParams) => void;
  isPublishing: boolean;
}) => {
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [reward, setReward] = useState("");
  const [duration, setDuration] = useState("7"); // Default 7 days

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title || !description || !reward || !duration) {
      alert("Please fill out all fields.");
      return;
    }
    onPublish({
      title,
      description,
      reward: parseInt(reward, 10),
      duration: parseInt(duration, 10) * 24 * 60 * 60, // Convert days to seconds
    });
  };

  return (
    <form onSubmit={handleSubmit} className="publish-form">
      <h2>Publish a New Task</h2>
      <p className="notice">
        Connected to shared-config. Tasks will be published to blockchain in
        next version.
      </p>
      <input
        type="text"
        placeholder="Task Title"
        value={title}
        onChange={(e) => setTitle(e.target.value)}
        disabled={isPublishing}
      />
      <textarea
        placeholder="Task Description"
        value={description}
        onChange={(e) => setDescription(e.target.value)}
        disabled={isPublishing}
      />
      <input
        type="number"
        placeholder="Reward (xPNTs)"
        value={reward}
        onChange={(e) => setReward(e.target.value)}
        disabled={isPublishing}
        min="1"
      />
      <input
        type="number"
        placeholder="Duration (days)"
        value={duration}
        onChange={(e) => setDuration(e.target.value)}
        disabled={isPublishing}
        min="1"
        max="30"
      />
      <button type="submit" disabled={isPublishing}>
        {isPublishing ? "Publishing..." : "Publish Task"}
      </button>
    </form>
  );
};

// --- MAIN APP ---

function App() {
  // State
  const [userAccount, setUserAccount] = useState<string | null>(null);
  const [ethBalance, setEthBalance] = useState<string | null>(null);
  const [apntsBalance, setApntsBalance] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [tasks, setTasks] = useState<Task[]>([]);
  const [view, setView] = useState<"list" | "publish">("list");
  const [isPublishing, setIsPublishing] = useState(false);
  const [isRegistered, setIsRegistered] = useState<boolean>(false);

  // --- TASK MANAGEMENT ---
  // Load tasks from service
  const loadTasks = async () => {
    try {
      const taskList = await taskService.getTasks();
      setTasks(taskList);
    } catch (error) {
      console.error("Failed to load tasks:", error);
    }
  };

  // Initialize task service when user connects
  useEffect(() => {
    if (userAccount && typeof window.ethereum !== "undefined") {
      const initializeTaskService = async () => {
        try {
          const provider = new ethers.BrowserProvider(window.ethereum);
          const signer = await provider.getSigner();
          await taskService.initialize(signer);
          await loadTasks();
        } catch (error) {
          console.error("Failed to initialize task service:", error);
        }
      };

      initializeTaskService();
    }
  }, [userAccount]);

  // Check if current user's community is registered
  useEffect(() => {
    const checkRegistration = async () => {
      if (userAccount && ownerSigner) {
        try {
          const registered = await isRegisteredCommunity(
            userAccount,
            jsonRpcProvider,
          );
          setIsRegistered(registered);
        } catch (error) {
          console.error("Failed to check community registration:", error);
        }
      }
    };

    checkRegistration();
  }, [userAccount, ownerSigner]);

  const canPublish = useMemo(() => {
    return (
      userAccount &&
      ownerSigner &&
      userAccount.toLowerCase() === ownerSigner.address.toLowerCase() &&
      isRegistered
    );
  }, [userAccount, ownerSigner, isRegistered]);

  // Handlers
  const connectWallet = async () => {
    setError(null);
    setApntsBalance(null);
    if (!window.ethereum) {
      return setError(
        "MetaMask is not installed. Please install it to use this app.",
      );
    }
    try {
      const browserProvider = new ethers.BrowserProvider(window.ethereum);
      await browserProvider.send("eth_requestAccounts", []);
      const userSigner = await browserProvider.getSigner();
      const address = await userSigner.getAddress();
      setUserAccount(address);

      // Get ETH balance from user's wallet
      const balanceWei = await browserProvider.getBalance(address);
      setEthBalance(ethers.formatEther(balanceWei));

      // Get aPNTs balance from user's wallet
      const apntsContract = new ethers.Contract(
        APNTS_CONTRACT_ADDRESS,
        APNTS_ABI,
        browserProvider,
      );
      const balanceApnts = await apntsContract.balanceOf(address);
      setApntsBalance(ethers.formatUnits(balanceApnts, 18));
    } catch (err: any) {
      setError(err.message || "Failed to connect wallet.");
    }
  };

  const handlePublishTask = async (newTaskData: CreateTaskParams) => {
    if (!canPublish) {
      alert("You must be a registered community owner to publish tasks.");
      return;
    }

    setIsPublishing(true);
    console.log("Publishing task with new task service...");
    console.log("Publisher:", userAccount);
    console.log("Task Data:", newTaskData);

    try {
      const taskId = await taskService.publishTask(newTaskData);
      console.log("Task published successfully with ID:", taskId);

      // Refresh task list
      await loadTasks();

      setIsPublishing(false);
      setView("list");

      alert("Task published successfully!");
    } catch (error: any) {
      setError("Task publication failed: " + error.message);
      setIsPublishing(false);
    }
  };

  const handleApplyForTask = async (taskId: number) => {
    if (!userAccount) {
      alert("Please connect your wallet to apply for a task.");
      return;
    }

    try {
      await taskService.applyForTask({ taskId });
      console.log(`User ${userAccount} applied for task ${taskId}`);

      // Refresh task list
      await loadTasks();

      alert("Task application successful!");
    } catch (error: any) {
      setError("Failed to apply for task: " + error.message);
    }
  };

  return (
    <div className="app-container">
      <header className="app-header">
        <h1>COS72 Task Square</h1>
        <div className="wallet-info">
          {userAccount ? (
            <div>
              <p>
                <strong>Your Wallet:</strong>{" "}
                {`${userAccount.substring(0, 6)}...${userAccount.substring(userAccount.length - 4)}`}
              </p>
              <p>
                <strong>ETH:</strong>{" "}
                {ethBalance ? `${parseFloat(ethBalance).toFixed(4)}` : "..."}
              </p>
              <p>
                <strong>aPNTs:</strong>{" "}
                {apntsBalance
                  ? `${parseFloat(apntsBalance).toFixed(2)}`
                  : "..."}
              </p>
            </div>
          ) : (
            <button onClick={connectWallet}>Connect Wallet</button>
          )}
        </div>
      </header>

      <main>
        {error && <p className="error-message">{error}</p>}

        <div className="notice">
          <strong>SHARED-CONFIG INTEGRATED:</strong> Using @aastar/shared-config
          for contract addresses and ABIs. Task service connected with mock
          implementation.
        </div>

        {!isRegistered && userAccount && ownerSigner && (
          <div className="warning-message">
            <strong>⚠️ Community Not Registered:</strong> Your community must be
            registered in Registry to publish tasks.
          </div>
        )}

        {canPublish && view === "list" && (
          <button
            onClick={() => setView("publish")}
            className="publish-toggle-button"
          >
            Publish New Task
          </button>
        )}

        {view === "publish" ? (
          <>
            <button onClick={() => setView("list")} className="back-button">
              ← Back to Task List
            </button>
            <PublishTaskForm
              onPublish={handlePublishTask}
              isPublishing={isPublishing}
            />
          </>
        ) : (
          <div className="task-list">
            {tasks.map((task) => (
              <TaskCard
                key={task.id}
                task={task}
                onApply={handleApplyForTask}
              />
            ))}
          </div>
        )}
      </main>
    </div>
  );
}

export default App;
