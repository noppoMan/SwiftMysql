//
//  ThreadUnsafeEventEmitter.swift
//  SwiftMysqlPackageDescription
//
//  Created by Yuki Takei on 2017/11/08.
//

import Foundation

class ThreadUnsafeEventEmitter<T> {
    
    var onceListenersCount: Int {
        return onceListeners.count
    }
    
    var onListenersCount: Int {
        return onListeners.count
    }
    
    private var onceListeners: [(T) -> Void] = []
    
    private var onListeners: [(T) -> Void] = []
    
    init() {}
    
    func emit(with value: T) {
        defer {
            onceListeners.removeAll()
        }
        
        for handle in onceListeners {
            handle(value)
        }
        
        for handle in onListeners {
            handle(value)
        }
    }
    
    func once(handler: @escaping (T) -> Void) {
        onceListeners.append(handler)
    }
    
    func on(handler: @escaping (T) -> Void) {
        onListeners.append(handler)
    }
}
