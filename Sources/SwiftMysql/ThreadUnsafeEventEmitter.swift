//
//  ThreadUnsafeEventEmitter.swift
//  SwiftMysqlPackageDescription
//
//  Created by Yuki Takei on 2017/11/08.
//

import Foundation

/**
 Thread safety EventEmitter
 */
public class ThreadUnsafeEventEmitter<T> {
    
    public var onceListenersCount: Int {
        return onceListeners.count
    }
    
    public var onListenersCount: Int {
        return onListeners.count
    }
    
    private var onceListeners: [(T) -> Void] = []
    
    private var onListeners: [(T) -> Void] = []
    
    public init() {}
    
    public func emit(with value: T) {
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
    
    public func once(handler: @escaping (T) -> Void) {
        onceListeners.append(handler)
    }
    
    public func on(handler: @escaping (T) -> Void) {
        onListeners.append(handler)
    }
}
