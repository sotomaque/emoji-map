import Foundation
import os.log

/// Manages async tasks with thread-safe access and proper cancellation
class TaskManager {
    // Logger for debugging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "TaskManager")
    
    // Serial queue for thread synchronization
    private let taskQueue = DispatchQueue(label: "com.emoji-map.taskQueue")
    
    // Task storage with thread-safe access
    private var taskStorage: [String: Task<Void, Never>] = [:]
    
    /// Get a task by key
    func getTask(forKey key: String) -> Task<Void, Never>? {
        return taskQueue.sync {
            return taskStorage[key]
        }
    }
    
    /// Set a task for a key, cancelling any existing task
    func setTask(_ task: Task<Void, Never>?, forKey key: String) {
        taskQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Cancel existing task before assigning a new one
            if let existingTask = self.taskStorage[key], task != nil {
                self.logger.debug("Cancelling existing task for key: \(key)")
                existingTask.cancel()
            }
            
            // Store the new task
            self.taskStorage[key] = task
            
            if task != nil {
                self.logger.debug("Set new task for key: \(key)")
            } else {
                self.logger.debug("Cleared task for key: \(key)")
            }
        }
    }
    
    /// Cancel a task by key
    func cancelTask(forKey key: String) {
        taskQueue.async { [weak self] in
            guard let self = self else { return }
            
            if let task = self.taskStorage[key] {
                self.logger.debug("Cancelling task for key: \(key)")
                task.cancel()
                self.taskStorage[key] = nil
            }
        }
    }
    
    /// Cancel all tasks
    func cancelAllTasks() {
        taskQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.logger.notice("Cancelling all \(self.taskStorage.count) tasks")
            
            for (key, task) in self.taskStorage {
                self.logger.debug("Cancelling task for key: \(key)")
                task.cancel()
            }
            
            self.taskStorage.removeAll()
        }
    }
} 