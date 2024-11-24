# Worker Task Allocation Algorithm Documentation

## Overview

The `WorkerTaskAllocation` smart contract implements an algorithm for allocating both divisible and indivisible tasks to workers based on their expertise, availability, and wage requirements. The system manages worker registration, task creation, task assignment, and completion tracking.

## Key Components

1. **Worker**: Represented by a struct containing information about availability, expertise, minimum wage, earnings, and task completion history.
2. **Task**: Represented by a struct containing information about required time, expertise level, dependencies, wage, deadline, divisibility, and assigned workers.
3. **Task Lists**: Separate arrays for divisible and indivisible tasks.
4. **Deadline Mapping**: A mapping of deadlines to task IDs for efficient task processing.

## Core Algorithms

### 1. Worker Registration

When a worker registers:
1. Create a new `Worker` struct with provided details.
2. Increment the worker count.
3. Attempt to assign indivisible tasks to the new worker.
4. Attempt to allocate divisible tasks to the new worker.

### 2. Task Addition

When a task is added:
1. Create a new `Task` struct with provided details.
2. Add the task to either the divisible or indivisible task list.
3. Update the deadline-to-tasks mapping.
4. Update parent tasks' children arrays if dependencies exist.
5. Attempt to assign the new task to all registered workers.

### 3. Indivisible Task Assignment

The `assignWorkerToIndivisibleTasks` function:
1. Iterate through the indivisible tasks list.
2. For each unassigned task:
   - Check if the worker meets all requirements (availability, expertise, wage).
   - Check if all task dependencies are completed.
   - If all conditions are met, assign the task to the worker.
   - Update the worker's available hours and last free time.
   - If the worker's hours are exhausted, deregister them.

### 4. Divisible Task Allocation

The `allocateDivisibleTasks` function:
1. Get a list of eligible divisible tasks for the worker.
2. Sort tasks by expertise level (ascending).
3. Iterate through eligible tasks (highest expertise first):
   - Calculate the hours the worker can contribute to the task.
   - If the worker can complete the work before the deadline:
     - Assign the worker to the task.
     - Update the task's required time and the worker's available hours.
     - If the task is fully assigned, mark it as completed.
     - If the worker's hours are exhausted, deregister them.

### 5. Eligible Divisible Tasks Selection

The `getEligibleDivisibleTasks` function:
1. Iterate through all divisible tasks.
2. For each task, check if:
   - The task is not completed.
   - The worker has available hours.
   - The worker meets the expertise requirement.
   - The task's wage meets the worker's minimum wage.
   - All task dependencies are completed.
3. Return a sorted list of eligible task IDs.

### 6. Task Processing

The `processRecentTasks` function:
1. Consider tasks with deadlines in the last 14 minutes.
2. For each relevant deadline:
   - Process all tasks associated with that deadline.
   - For each task:
     - If not completed, calculate and transfer payments to assigned workers.

## Key Algorithms in Detail

### Task Sorting Algorithm

The `sortTasksByExpertiseLevel` function implements a simple bubble sort to arrange tasks by their expertise level in ascending order. This ensures that workers are assigned to tasks that best match their skill level, prioritizing more complex tasks.

### Dependency Checking

The `dependenciesCompleted` function checks if all dependencies of a given task have been completed. This ensures that tasks are only assigned when their prerequisites have been met.

## Optimization Strategies

1. **Eager Assignment**: Tasks are attempted to be assigned immediately upon creation or when a new worker registers, maximizing resource utilization.
2. **Prioritization**: Divisible tasks are sorted by expertise level, ensuring that highly skilled workers are assigned to the most challenging tasks first.
3. **Flexible Allocation**: Divisible tasks can be partially assigned to multiple workers, allowing for efficient use of available worker hours.


## API Documentation

This server application is built with Node.js and Express. It interacts with an Ethereum smart contract to manage and execute tasks, as well as register, retrieve, and deregister worker details. It has been freely deployed over Vercel

## Setup

Ensure you have the following dependencies installed:
- `express`
- `ethers`
- `node-schedule`

## Endpoints

### 1. Create Task

**URL:** `/create-task`  
**Method:** `POST`

**Description:**  
Creates a new task and schedules it for execution at a specified time.

**Request Body:**
- `epochTime` (number): The Unix timestamp when the task should be executed.
- `timeRequired` (number): The time required to complete the task.
- `level` (number): The level required to execute the task.
- `dependencies` (array): Array of dependencies for the task.
- `wage` (number): The wage offered for the task.
- `divisible` (boolean): Indicates whether the task can be divided among multiple workers.

**Response:**  
- `taskNumber` (number): The unique identifier for the created task.

### 2. Register Worker

**URL:** `/register-worker`  
**Method:** `POST`

**Description:**  
Registers a new worker with the specified details.

**Request Body:**
- `walletAdd` (string): The worker's wallet address.
- `level` (number): The worker's level.
- `avb` (number): Availability status of the worker.
- `wage` (number): The wage the worker expects.

**Response:**  
- `walletAdd`: Confirmation that the worker was added.

### 3. Get Worker Details

**URL:** `/get-worker`  
**Method:** `POST`

**Description:**  
Fetches details of a registered worker.

**Request Body:**
- `walletAdd` (string): The worker's wallet address.

**Response:**
- `hours` (number): The total hours worked.
- `level` (number): The worker's level.
- `wage` (number): The worker's wage.
- `totalEarnings` (number): The total earnings of the worker.
- `completedTask` (number): The number of tasks completed by the worker.
- `isRegistered` (boolean): Whether the worker is registered.

### 4. Get Task Details

**URL:** `/get-task`  
**Method:** `POST`

**Description:**  
Fetches details of a specific task.

**Request Body:**
- `taskId` (number): The unique identifier of the task.

**Response:**
- `hours` (number): The total hours required for the task.
- `level` (number): The level required to complete the task.
- `wage` (number): The wage offered for the task.
- `deadline` (number): The deadline for task completion.
- `isDivisible` (boolean): Indicates whether the task is divisible.
- `assignedWorkers` (array): The list of workers assigned to the task.
- `isComplete` (boolean): Indicates if the task is completed.

### 5. Deregister Worker

**URL:** `/delete-register`  
**Method:** `POST`

**Description:**  
Deregisters a worker from the system.

**Request Body:**
- `workerId` (string): The unique identifier of the worker to be deregistered.

**Response:**  
- `workerId`: Confirmation that the worker was deregistered.

## Helper Functions

### `executeTask(taskNumber)`

**Description:**  
Executes the task associated with the given `taskNumber`. Retrieves worker details from the smart contract and logs them.

**Parameters:**
- `taskNumber` (number): The unique identifier of the task to execute.

---

## Running the Server

Run the server with the following command:

```bash
node server.js
