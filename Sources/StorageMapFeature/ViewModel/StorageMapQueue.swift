import StorageFixCore

extension StorageMapViewModel {
    public var usesReviewQueue: Bool { queue != nil }
    public var isQueueBusy: Bool { queue?.snapshot.isExecuting == true }
    public var canQueueSelection: Bool {
        usesReviewQueue && !isLoading && !isQueueBusy && selectedItem?.isFolder == false
            && inventoryResult?.options == InventoryOptions() && inventoryResult?.wasCancelled != true
            && inventoryResult?.volume?.isReadOnly != true
    }
    public func addSelectionToQueue() {
        guard canQueueSelection, let item = selectedItem, let queue else { return }
        let result = queue.add(paths: [item.path], origin: .map)
        queueAddResult = result
        resultMessage = result.message + " Open Review Queue to continue."
    }
    func invalidateAfterQueue() {
        resetInventory()
        resultMessage = "Queue operation finished. Scan again to refresh the map."
    }
}
