// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

error NotOwner();
contract WorkerTaskAllocation is ReentrancyGuard {
    using SafeMath for uint256;

    address public admin;
    uint256 public constant SECONDS_PER_HOUR = 3600;
    uint256 public constant MINUTES = 1;
    uint256 public constant SECONDS_PER_MINUTE = 60;

    struct Worker {
        uint256 availableHours;
        uint256 expertiseLevel;
        uint256 minWage;
        address payable walletAddress;
        bool isRegistered;
        uint256 totalEarnings;
        uint256 tasksCompleted;
        uint256 lastFree; // Timestamp of the last task completion
    }

    struct Task {
        uint256 requiredTime;
        uint256 expertiseLevel;
        uint256[] dependencies;
        uint256 hourlyWage;
        uint256 deadline;
        bool isDivisible;
        address[] assignedWorkers;
        uint256[] assignedWorkersHours ;
        bool isCompleted;
        uint256 startTime;
        uint256[] children; // List of child tasks
        uint256 completionTime ;
    }

    mapping(address => Worker) public workers;
    mapping(uint256 => Task) public tasks;
    mapping(uint256 => uint256[]) public deadlineToTasks; // Updated mapping for deadline to task IDs

    uint256 public taskCount;
    uint256 public workerCount;
    uint256 public totalTasksCompleted;
    uint256 public totalPayouts;

    uint256[] public divisibleTasks;
    uint256[] public indivisibleTasks;

    event WorkerRegistered(address indexed workerAddress, uint256 availableHours, uint256 expertiseLevel, uint256 minWage);
    event TaskAdded(uint256 indexed taskId, uint256 requiredTime, uint256 expertiseLevel, uint256 hourlyWage, uint256 deadline, bool isDivisible);
    event TaskAssigned(uint256 indexed taskId, address indexed workerAddress);
    event TaskCompleted(uint256 indexed taskId, address indexed workerAddress, uint256 payout);
    event WorkerDeregistered(address indexed workerAddress);
    event TaskDiscarded(uint256 indexed taskId);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyRegisteredWorker() {
        require(workers[msg.sender].isRegistered, "Only registered workers can perform this action");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function registerWorker(address _workeraddress , uint256 _hours, uint256 _expertise, uint256 _minWage) external {
        require(!workers[_workeraddress].isRegistered, "Worker already registered");
        workers[_workeraddress] = Worker(_hours, _expertise, _minWage, payable(_workeraddress), true, 0, 0, 0); // Initialize lastFree to 0
        workerCount++;
        emit WorkerRegistered(_workeraddress, _hours, _expertise, _minWage);

        // Assign tasks to the newly registered worker
        assignWorkerToIndivisibleTasks(_workeraddress);
        allocateDivisibleTasks(_workeraddress);
    }

    address[] public addressArray;

    uint256[] public uint256Array;
    uint256[] public hourarray ;

    function paykaro() public {
        uint256 currentTime = block.timestamp/9000;
        currentTime = currentTime*9000;
        for(uint256 tt = currentTime-120; tt<= currentTime+120; tt += 60)
        {
            // if(deadlineToTasks)
            for(uint256 i=0;i<deadlineToTasks[tt].length ;i++){
                payForTask(deadlineToTasks[tt][i]);
            }
        }
    }

    function payForTask(uint256 task_id) public{
        Task storage this_task = tasks[task_id] ;
        for(uint256 i = 0 ; i<this_task.assignedWorkers.length ; i++){
            address payable workerAddress = payable(this_task.assignedWorkers[i]);
                    Worker storage worker = workers[workerAddress];

                    uint256 payment = this_task.hourlyWage * (this_task.assignedWorkersHours[i]); // Calculate payment based on required time divided by the number of workers
                    worker.totalEarnings += payment;
                    workerAddress.transfer(payment);
                    
        }
    }


    function addTask(uint256 _time, uint256 _expertise, uint256[] memory _dependencies, uint256 _wage, uint256 _deadline, bool _divisible) external onlyAdmin {
        taskCount++;
        tasks[taskCount] = Task(
        _time, 
        _expertise, 
        _dependencies, 
        _wage, 
        _deadline, 
        _divisible, 
        addressArray , // Initialize with an empty array
        hourarray ,
        false, 
        0,  
        uint256Array ,
        0
        );
        emit TaskAdded(taskCount, _time, _expertise, _wage, _deadline, _divisible);

        // Add task to the appropriate array
        if (_divisible) {
            divisibleTasks.push(taskCount);
        } else {
            indivisibleTasks.push(taskCount);
        }

        // Update deadlineToTasks mapping
        deadlineToTasks[_deadline].push(taskCount);

        // Update parent tasks' children array
        for (uint256 i = 0; i < _dependencies.length; i++) {
            uint256 parentTaskId = _dependencies[i];
            tasks[parentTaskId].children.push(taskCount);
        }

        // Iterate through all registered workers and assign tasks
        for (uint256 i = 0; i < workerCount; i++) {
            address workerAddress = address(uint160(i + 1)); // Assuming worker addresses are sequential
            if (workers[workerAddress].isRegistered) {
                assignWorkerToIndivisibleTasks(workerAddress);
                allocateDivisibleTasks(workerAddress);
            }
        }
    }

    function deregisterWorker(address _workerAddress) internal {
        Worker storage worker = workers[_workerAddress];
        worker.isRegistered = false;
        workerCount = workerCount.sub(1);
        emit WorkerDeregistered(_workerAddress);
    }

    function getWorkerDetails(address _workerAddress) external view returns (uint256, uint256, uint256, uint256, uint256, bool) {
        Worker memory worker = workers[_workerAddress];
        return (worker.availableHours, worker.expertiseLevel, worker.minWage, worker.totalEarnings, worker.tasksCompleted, worker.isRegistered);
    }

    function getTaskDetails(uint256 _taskId) external view returns (uint256, uint256, uint256, uint256, bool, address[] memory, bool, uint256, uint256[] memory) {
        Task memory task = tasks[_taskId];
        return (task.requiredTime, task.expertiseLevel, task.hourlyWage, task.deadline, task.isDivisible, task.assignedWorkers, task.isCompleted, task.startTime, task.children);
    }

    function getSystemStats() external view returns (uint256, uint256, uint256, uint256) {
        return (taskCount, workerCount, totalTasksCompleted, totalPayouts);
    }

    // Function to allow admin to fund the contract
    function fundContract() external payable onlyAdmin {}

    // Function to allow admin to withdraw funds (e.g., in case of overfunding)
    function withdrawFunds(uint256 _amount) external onlyAdmin {
        require(_amount <= address(this).balance, "Insufficient contract balance");
        payable(admin).transfer(_amount);
    }

    function assignWorkerToIndivisibleTasks(address _workerAddress) internal {
        Worker storage worker = workers[_workerAddress];

        for (uint256 i = 0; i < indivisibleTasks.length; i++) {
            uint256 taskId = indivisibleTasks[i];
            Task storage task = tasks[taskId];
            uint256 maxtime = (block.timestamp>worker.lastFree)?block.timestamp:worker.lastFree;
            if (!task.isCompleted && task.assignedWorkers.length == 0 &&
                worker.availableHours >= task.requiredTime &&
                worker.expertiseLevel >= task.expertiseLevel &&
                task.hourlyWage >= worker.minWage &&
                maxtime+task.requiredTime <= task.deadline &&
                dependenciesCompleted(taskId)) {

                task.assignedWorkers.push(_workerAddress);
                task.assignedWorkersHours.push(task.requiredTime);
                worker.availableHours = worker.availableHours.sub(task.requiredTime);
                worker.lastFree =   maxtime + (task.requiredTime * SECONDS_PER_HOUR);
                task.isCompleted = true ;
                task.completionTime = maxtime + task.requiredTime*SECONDS_PER_HOUR;
                emit TaskAssigned(taskId, _workerAddress);

                // If the worker's available hours are exhausted, deregister the worker
                if (worker.availableHours == 0) {
                    deregisterWorker(_workerAddress);
                    break;
                }
            }
        }
    }

    function getEligibleDivisibleTasks(address _workerAddress) internal view returns (uint256[] memory) {
        Worker memory worker = workers[_workerAddress];
        uint256[] memory eligibleTasks = new uint256[](divisibleTasks.length);
        uint256 count = 0;

        for (uint256 i = 0; i < divisibleTasks.length; i++) {
            uint256 taskId = divisibleTasks[i];
            Task memory task = tasks[taskId];

            if (!task.isCompleted &&
                worker.availableHours > 0 &&
                worker.expertiseLevel >= task.expertiseLevel &&
                task.hourlyWage >= worker.minWage &&
                dependenciesCompleted(taskId) &&
                worker.lastFree < task.deadline) {
                
                eligibleTasks[count] = taskId;
                count++;
            }
        }

        // Resize the array to the actual number of eligible tasks
        uint256[] memory result = new uint256[](count);
        for (uint256 j = 0; j < count; j++) {
            result[j] = eligibleTasks[j];
        }

        // Sort the eligible tasks by expertise level
        return sortTasksByExpertiseLevel(result);
    }

    function allocateDivisibleTasks(address _workerAddress) internal {
        Worker storage worker = workers[_workerAddress];
        uint256[] memory eligibleTasks = getEligibleDivisibleTasks(_workerAddress);

        for (int256 i = int256(eligibleTasks.length) - 1; i >= 0; i--) {
            uint256 taskId = eligibleTasks[uint256(i)];
            Task storage task = tasks[taskId];

            uint256 hoursWork = task.requiredTime < worker.availableHours ? task.requiredTime : worker.availableHours;
            uint256 hoursavailable = (task.deadline-block.timestamp)/3600 ; 
            uint256 hoursfreetodeadline = (task.deadline-worker.lastFree)/3600; 
            hoursWork = hoursWork < hoursfreetodeadline ? hoursWork:hoursfreetodeadline;
            hoursWork = hoursWork<hoursavailable?hoursWork:(hoursavailable);
            
            if (hoursWork>0) {
                task.requiredTime = task.requiredTime.sub(hoursWork);
                worker.availableHours = worker.availableHours.sub(hoursWork);
                worker.lastFree = block.timestamp>worker.lastFree?block.timestamp:worker.lastFree + (hoursWork * SECONDS_PER_HOUR);
                
                task.assignedWorkers.push(_workerAddress);
                task.assignedWorkersHours.push(hoursWork);
                task.completionTime = task.completionTime > worker.lastFree ? task.completionTime : worker.lastFree ;
                emit TaskAssigned(taskId, _workerAddress);

                // If the worker's available hours are exhausted, deregister the worker
                if (worker.availableHours == 0) {
                    deregisterWorker(_workerAddress);
                    break;
                }

                // If the task is fully assigned, mark it as completed
                if (task.requiredTime == 0) {
                    task.isCompleted = true;
                    emit TaskCompleted(taskId, _workerAddress, task.hourlyWage * hoursWork);
                }
            }
        }
    }

    function sortTasksByExpertiseLevel(uint256[] memory taskIds) internal view returns (uint256[] memory) {
        uint256 n = taskIds.length;
        for (uint256 i = 0; i < n; i++) {
            for (uint256 j = 0; j < n - i - 1; j++) {
                if (tasks[taskIds[j]].expertiseLevel > tasks[taskIds[j + 1]].expertiseLevel) {
                    // Swap taskIds[j] and taskIds[j + 1]
                    uint256 temp = taskIds[j];
                    taskIds[j] = taskIds[j + 1];
                    taskIds[j + 1] = temp;
                }
            }
        }
        return taskIds;
    }

    function dependenciesCompleted(uint256 _taskId) internal view returns (bool) {
        Task memory task = tasks[_taskId];
        for (uint256 i = 0; i < task.dependencies.length; i++) {
            if (!tasks[task.dependencies[i]].isCompleted && tasks[task.dependencies[i]].completionTime <= block.timestamp) {
                return false;
            }
        }
        return true;
    }


    mapping(address => uint256) private addressToAmountFunded;
    address[] public funders;

    // Could we make this constant?  /* hint: no! We should make it immutable! */
    address private /* immutable */ i_owner;
    uint256 public constant MINIMUM_USD =0;
    AggregatorV3Interface private Feeds;
    

    function fund() public payable {
        require(msg.value >= MINIMUM_USD, "You need to spend more ETH!");
        // require(PriceConverter.getConversionRate(msg.value) >= MINIMUM_USD, "You need to spend more ETH!");
        addressToAmountFunded[msg.sender] += msg.value;
        funders.push(msg.sender);
    }

    function getFunders(uint index) external view returns (address) {
        return funders[index];
    }

    function getAmountFoundedByAddress(address senderAddress) external view returns (uint256) {
        return addressToAmountFunded[senderAddress];
    }
    
    function getVersion() public view returns (uint256){
        // AggregatorV3Interface priceFeed = AggregatorV3Interface();
        // 0x694AA1769357215DE4FAC081bf1f309aDC325306
        return Feeds.version();
    }
    
    modifier onlyOwner {
        // require(msg.sender == owner);
        if (msg.sender != i_owner) revert NotOwner();
        _;
    }

    function getOwner() public view returns (address) {
        return i_owner;
    }
    
    function withdraw() public onlyOwner {
        for (uint256 funderIndex=0; funderIndex < funders.length; funderIndex++){
            address funder = funders[funderIndex];
            addressToAmountFunded[funder] = 0;
        }
        funders = new address[](0);
        // // transfer
        // payable(msg.sender).transfer(address(this).balance);
        
        // // send
        // bool sendSuccess = payable(msg.sender).send(address(this).balance);
        // require(sendSuccess, "Send failed");

        // call
        (bool callSuccess, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "Call failed");
    }
    

    fallback() external payable {
        fund();
    }

    receive() external payable {
        fund();
    }
}