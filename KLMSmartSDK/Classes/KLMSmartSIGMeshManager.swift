//
//  KLMSmartSIGMeshManager.swift
//  KLMSmartSDK
//
//  Created by zhu yu on 2024/5/13.
//

import Foundation
import nRFMeshProvision

protocol KLMSmartSIGMeshManagerDelegate: AnyObject {
    func messageManager(_ manager: KLMSmartSIGMeshManager, didHandleGroup groupAddress: Address, deviceAddress: Address, error: Error?)
}

public class KLMSmartSIGMeshManager: NSObject {
    
    public static let shared = KLMSmartSIGMeshManager()
    private override init(){}
    
    weak var delegate:  KLMSmartSIGMeshManagerDelegate?
    
    /// 扫描蓝牙设备
    /// - Parameters:
    ///   - scanDevice: 扫描到的设备，用于设备连接和配网
    ///   - commandResult: 扫描结果
    public static func startSearch(scanDevice: @escaping ScanDevice, commandResult: @escaping CommandResult) {
        KLMSigScanManager.shared.startScan(scanDevice: scanDevice, commandResult: commandResult)
    }
    
    /// 停止扫描
    public static func stopScanning() {
        KLMSigScanManager.shared.stopScanning()
    }
    
    public static func startActive(device: DiscoveredPeripheral, unicastAddress: UInt16? = nil, activeSuccess: @escaping ActiveSuccess, activeFailure: @escaping ActiveFailure) {
        KLMSigConnectManager.shared.startConnect(discoveredPeripheral: device) { isSuccess, error in
            if isSuccess {
                ///连接成功，开始配网
                KLMSigActiveManager.shared.startActive(discoveredPeripheral: device, gattBearer: KLMSigConnectManager.shared.gattBearer!, unicastAddress: unicastAddress, activeSuccess: activeSuccess, activeFailure: activeFailure)
            } else {
                activeFailure(device, error)
            }
        }
    }
    
    public func addDeviceToGroup(device: Node, group: Group) throws {
        let manager = KLMSmartBleMesh.shared.meshNetworkManager!
        manager.delegate = self
        guard let model = KLMTool.getModelFromNode(node: device) else {
            print("Error: Model not found")
            throw KLMError.modelNotFound
        }
        if let message: ConfigMessage =
            ConfigModelSubscriptionAdd(group: group, to: model){
            
            do {
                try manager.send(message, to: device)
                
            } catch  {
                self.delegate?.messageManager(self, didHandleGroup: group.address.address, deviceAddress: device.unicastAddress, error: error)
            }
        }
    }
    
    public func deleteDeviceToGroup(device: Node, group: Group) throws {
        let manager = KLMSmartBleMesh.shared.meshNetworkManager!
        manager.delegate = self
        guard let model = KLMTool.getModelFromNode(node: device) else {
            print("Error: Model not found")
            throw KLMError.modelNotFound
        }
        if let message: ConfigMessage =
            ConfigModelSubscriptionDelete(group: group, from: model){
            
            do {
                try manager.send(message, to: device)
                
            } catch  {
                self.delegate?.messageManager(self, didHandleGroup: group.address.address, deviceAddress: device.unicastAddress, error: error)
            }
        }
    }
    
//    public func queryGroupMember(group: Group) -> [Node] {
//        var nodes: [Node] = [Node]()
//        let network = KLMSmartBleMesh.shared.meshNetworkManager.meshNetwork!
//        let models = network.models(subscribedTo: group)
//        for model in models {
//            let node = model.parentElement?.parentNode
//            nodes.append(node!)
//        }
//        return nodes
//    }
}

extension KLMSmartSIGMeshManager: MeshNetworkDelegate {
    
    public func meshNetworkManager(_ manager: MeshNetworkManager, didReceiveMessage message: MeshMessage, sentFrom source: Address, to destination: Address) {
        switch message {
        case let status as ConfigModelSubscriptionStatus://设备添加或者删除组
            
            if status.status == .success {
                
                self.delegate?.messageManager(self, didHandleGroup: status.address, deviceAddress: destination, error: nil)
            } else {
                let error = KLMError.error(status.message)
                self.delegate?.messageManager(self, didHandleGroup: status.address, deviceAddress: destination, error: error)
            }
            
        default:
            break
        }
    }
    
    public func meshNetworkManager(_ manager: MeshNetworkManager,
                            failedToSendMessage message: MeshMessage,
                            from localElement: Element, to destination: Address,
                            error: Error) {
        if let status: ConfigModelSubscriptionStatus = message as? ConfigModelSubscriptionStatus {
            self.delegate?.messageManager(self, didHandleGroup: status.address, deviceAddress: destination, error: error)
        }
    }
    
    public func meshNetworkManager(_ manager: MeshNetworkManager,
                            didSendMessage message: MeshMessage,
                            from localElement: Element, to destination: Address) {
        
       
    }
}

