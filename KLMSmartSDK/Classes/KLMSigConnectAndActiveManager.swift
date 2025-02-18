//
//  KLMSigConnectAndActiveManager.swift
//  KLM
//
//  Created by zhu yu on 2023/6/7.
//

import UIKit
import nRFMeshProvision

//class KLMSigConnectAndActiveManager: NSObject {
//    
//    static let shared = KLMSigConnectAndActiveManager()
//    private override init(){}
//    
//    var command: KLMSigMeshCommand?
//    var devices: [DiscoveredPeripheral]!
//    var currentIndex: Int = 0
//    
//    ///添加多个设备
//    func startConnectAndActive(devices: [DiscoveredPeripheral], activeSuccess: @escaping ActiveSuccess, activeFailure: @escaping ActiveFailure, didConnectDevice: @escaping DidConnectDevice, allFinish: @escaping AllFinish) {
//        
//        let command = KLMSigMeshCommand()
//        command.activeSuccess = activeSuccess
//        command.activeFailure = activeFailure
//        command.didConnectDevice = didConnectDevice
//        command.allFinish = allFinish
//        self.command = command
//        
//        //初始化
//        currentIndex = 0
//        self.devices = devices
//        startConnect()
//    }
//    
//    private func startConnect() {
//        
//        let device = devices[currentIndex]
//        KLMSigConnectManager.shared.startConnect(discoveredPeripheral: device) {[weak self] isSuccess, error in
//            guard let self = self else { return }
//            if isSuccess {
//                self.startActive()
//            } else {
//                if let failure = command?.activeFailure {
//                    DispatchQueue.main.async {
//                        failure(device, error!)
//                    }
//                }
//                self.nextDevice()
//            }
//        }
//        
//        if let didConnectDevice = command?.didConnectDevice {
//            DispatchQueue.main.async {
//                didConnectDevice(device)
//            }
//        }
//    }
//    
//    private func startActive() {
//        
//        let device = devices[currentIndex]
//        KLMSigActiveManager.shared.startActive(discoveredPeripheral: device, gattBearer: KLMSigConnectManager.shared.gattBearer!) { [weak self] node in
//            guard let self = self else { return }
//            if let success = command?.activeSuccess {
//                DispatchQueue.main.async {
//                    success(node)
//                }
//            }
//            self.nextDevice()
//        } activeFailure: {[weak self] device, error in
//            guard let self = self else { return }
//            if let failure = command?.activeFailure {
//                DispatchQueue.main.async {
//                    failure(device, error)
//                }
//            }
//            self.nextDevice()
//        }
//    }
//    
//    private func nextDevice() {
//        
//        if currentIndex >= devices.count - 1 {
//            if let allfinish = command?.allFinish {
//                DispatchQueue.main.async {
//                    allfinish(true)
//                }
//            }
//            return
//        }
//        
//        currentIndex += 1
//        //开始连接其他设备
//        startConnect()
//    }
//}



