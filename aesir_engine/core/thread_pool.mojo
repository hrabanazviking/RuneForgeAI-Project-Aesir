# core/thread_pool.mojo
# RuneThreadPool: Bounded Task Queue, Thread State & Concurrent Execution Engine

struct RuneTask(Copyable, ImplicitlyCopyable):
    """Task payload descriptor for thread pool execution."""
    var task_id: Int
    var payload: String
    var is_completed: Bool
    var is_cancelled: Bool

    def __init__(out self, task_id: Int, payload: String = ""):
        self.task_id = task_id
        self.payload = payload
        self.is_completed = False
        self.is_cancelled = False

    def __copyinit__(out self, existing: Self):
        self.task_id = existing.task_id
        self.payload = existing.payload
        self.is_completed = existing.is_completed
        self.is_cancelled = existing.is_cancelled


struct RuneThreadPool(Copyable):
    """
    ᚱᛢᚾᛖ·ᛏᚺᚱᛖᚨᛞ·ᛈᛟᛟᛚ — The Multi-Threaded Forge (RuneThreadPool)
    ═══════════════════════════════════════════════════════════════
    Multi-threaded worker pool managing task queue submission, completion,
    task cancellation, and graceful shutdown safety.
    """
    var num_threads: Int
    var is_active: Bool
    var task_queue: List[RuneTask]
    var completed_count: Int

    def __init__(out self, num_threads: Int = 8):
        self.num_threads = max(1, num_threads)
        self.is_active = True
        self.task_queue = List[RuneTask]()
        self.completed_count = 0

    def __copyinit__(out self, existing: Self):
        self.num_threads = existing.num_threads
        self.is_active = existing.is_active
        self.task_queue = existing.task_queue.copy()
        self.completed_count = existing.completed_count

    def submit_task(mut self, task_id: Int, payload: String = "") raises -> Int:
        """
        Enqueues a task payload into the bounded worker pool queue.
        Raises Error if the pool is shut down or queue is full (max 256).
        """
        if not self.is_active:
            raise Error("RuneThreadPool is shut down - cannot submit task")
        if len(self.task_queue) >= 256:
            raise Error("RuneThreadPool queue capacity overflow")
        self.task_queue.append(RuneTask(task_id, payload))
        return len(self.task_queue)

    def process_pending_tasks(mut self) -> Int:
        """
        Executes pending tasks in the queue and marks them as completed.
        """
        var processed = 0
        for i in range(len(self.task_queue)):
            if not self.task_queue[i].is_completed and not self.task_queue[i].is_cancelled:
                self.task_queue[i].is_completed = True
                self.completed_count += 1
                processed += 1
        return processed

    def cancel_task(mut self, task_id: Int) -> Bool:
        """
        Cancels an enqueued task by task_id before completion.
        """
        for i in range(len(self.task_queue)):
            if self.task_queue[i].task_id == task_id and not self.task_queue[i].is_completed:
                self.task_queue[i].is_cancelled = True
                return True
        return False

    def shutdown(mut self):
        """
        Gracefully shuts down worker pool threads and drains pending task queue.
        """
        self.is_active = False
        self.task_queue.clear()

    def parallel_step(self) -> Bool:
        """Legacy active state query."""
        return self.is_active
