//
//  KLMSmartNode.swift
//  KLM
//
//  Created by 朱雨 on 2021/7/19.
//

import UIKit
import nRFMeshProvision

public protocol KLMSmartNodeDelegate: AnyObject {
    
    func smartNode(_ manager: KLMSmartNode, didReceiveVendorMessage message: responseParame?)
    
    func smartNodeDidResetNode(_ manager: KLMSmartNode)
    
    func smartNode(_ manager: KLMSmartNode, didfailure error: KLMMessageError?)
}

public extension KLMSmartNodeDelegate {
    
    func smartNode(_ manager: KLMSmartNode, didReceiveVendorMessage message: responseParame?){
        
    }
    
    func smartNodeDidResetNode(_ manager: KLMSmartNode){
        
    }
    
    func smartNode(_ manager: KLMSmartNode, didfailure error: KLMMessageError?){
        
    }
}

public class KLMSmartNode: NSObject {
    
    var currentNode: Node?
    var command: KLMSigMeshCommand?
    
    static let shared = KLMSmartNode()
    private override init(){
        super.init()
    }
    
    weak var delegate: KLMSmartNodeDelegate?
    
    public func setDeviceData(_ parame: requestparame, toNode node: Node) {
        
        if let model = KLMTool.getModelFromNode(node: node) {
            
            let manager = KLMSmartBleMesh.shared.meshNetworkManager!
            
            var parameString: String?
            if let intParame: Int = parame.dpValue as? Int {
                parameString = intParame.decimalTo2Hexadecimal()
            } else if let stringParame: String = parame.dpValue as? String {
                parameString = stringParame
            } else {
                let error = KLMMessageError(dpId: parame.dpId, error: KLMError.invalidParameter)
                self.delegate?.smartNode(self, didfailure: error)
                return
            }
            
            let dpString = parame.dpId.decimalTo2Hexadecimal()
            
            currentNode = node
            manager.delegate = self
            ///开始定时
            let command = KLMSigMeshCommand()
            command.timeout = 6
            self.command = command
            
            if let opCode = UInt8("1A", radix: 16) {
                let parameters = Data(hex: dpString + (parameString ?? ""))
                let message = RuntimeVendorMessage(opCode: opCode, for: model, parameters: parameters)
                do {
                    
                    command.messageHandle = try manager.send(message, to: model)
                } catch {
                    let error1 = KLMMessageError(dpId: parame.dpId, error: error)
                    self.delegate?.smartNode(self, didfailure: error1)
                }
            }
        } else {
            print("Error: Model not found")
            let error = KLMMessageError(dpId: parame.dpId, error: KLMError.modelNotFound)
            self.delegate?.smartNode(self, didfailure: error)
        }
    }
    
    public func getDeviceData(_ parame: requestparame, toNode node: Node) {
        
        let manager = KLMSmartBleMesh.shared.meshNetworkManager!
        
        if let model = KLMTool.getModelFromNode(node: node) {
            
            let dpString = parame.dpId.decimalTo2Hexadecimal()
            
            currentNode = node
            manager.delegate = self
            
            let command = KLMSigMeshCommand()
            command.timeout = 6
            self.command = command
            
            if let opCode = UInt8("1C", radix: 16) {
                let parameters = Data(hex: dpString)
                let message = RuntimeVendorMessage(opCode: opCode, for: model, parameters: parameters)
                do {
                    command.messageHandle = try manager.send(message, to: model)
                } catch  {
                    let error1 = KLMMessageError(dpId: parame.dpId, error: error)
                    self.delegate?.smartNode(self, didfailure: error1)
                }
            }
        } else {
            print("Error: Model not found")
            let error = KLMMessageError(dpId: parame.dpId, error: KLMError.modelNotFound)
            self.delegate?.smartNode(self, didfailure: error)
        }
    }
    
    /// 删除节点
    public func resetNode(node: Node) {
        
        currentNode = node
        let manager = KLMSmartBleMesh.shared.meshNetworkManager!
        manager.delegate = self
        
        let command = KLMSigMeshCommand()
        command.timeout = 6
        self.command = command
        
        let message = ConfigNodeReset()
        do {
            command.messageHandle = try manager.send(message, to: node)
        } catch  {
            let error1 = KLMMessageError(error: error)
            self.delegate?.smartNode(self, didfailure: error1)
        }
    }
    
    private func handleMessage(opcode: OpCodeType, status: UInt8, dpData: UInt8, value: Data) {
        
        var response = responseParame()
        response.opCodeType = opcode
        response.dpId = Int(dpData)
                            
        if status != 0 { ///error

            var err = KLMMessageError(errorCode: Int(status), dpId: Int(dpData))
            var errorInfo: String?
            switch status {
            case 1:
                if dpData == 12 {
                    errorInfo = NSLocalizedString("The light failed to connect to WiFi. Maybe the WiFi password is incorrect", comment: "")
                }
                if dpData == 15 {
                    errorInfo = NSLocalizedString("The device do not support", comment: "")
                }
                if dpData == 23 {
                    errorInfo = "标定数据传输失败，请检查网络。"
                }
                if dpData == 99 {
                    errorInfo = NSLocalizedString("Failed to connect to Network", comment: "")
                }
                if dpData == 13 {
                    errorInfo = NSLocalizedString("Data exception", comment: "")
                }
            case 2:
                errorInfo = NSLocalizedString("Please turn the light on", comment: "")
            case 3:
                errorInfo = NSLocalizedString("Light locked, please contact seller", comment: "")
            case 4: ///设备WiFi爆出的错误。
                errorInfo = NSLocalizedString("This may be a 5 GHz Wi-Fi, or Wi-Fi could not be found", comment: "")
            case 5:
                errorInfo = NSLocalizedString("The device is too far away from Wi-Fi Router,so it can not connect to Wi-Fi", comment: "")
            case 0xFF:
                errorInfo = NSLocalizedString("The device do not support", comment: "")
            case 0xFE:
                errorInfo = NSLocalizedString("Sensor failure", comment: "")
            case 0xFB:
                errorInfo = NSLocalizedString("The temperature of sensor is too high", comment: "")
            case 0xFA:
                errorInfo = NSLocalizedString("Spotlight is in demo mode.The time interval in 'Auto Mode' should be more than 10 minutes.", comment: "")
            case 0xFC:
                errorInfo = NSLocalizedString("Product popularity sensor failured", comment: "")
            case 0xFD:
                errorInfo = NSLocalizedString("Auto Mode sensor failure", comment: "")
            default:
                errorInfo = NSLocalizedString("Data exception", comment: "")
            }
            print("Error : \(errorInfo ?? "")")
            err.error = KLMError.error(errorInfo)
            self.delegate?.smartNode(self, didfailure: err)
            return
        }
        
        if value.count == 0 { ///没有字节
            var err = KLMMessageError(errorCode: Int(status), dpId: Int(dpData))
            let errorInfo = NSLocalizedString("Data exception", comment: "")
            err.error = KLMError.error(errorInfo)
            self.delegate?.smartNode(self, didfailure: err)
            return
        }
        
        //返回成功也要卡住一些错误数据
        switch dpData {
        case 12:
            if value.count > 7 { ///数据有误
                var err = KLMMessageError(errorCode: Int(status), dpId: Int(dpData))
                let errorInfo = NSLocalizedString("The device do not support", comment: "")
                err.error = KLMError.error(errorInfo)
                self.delegate?.smartNode(self, didfailure: err)
                return
            }
        default:
            break
        }
        response.dpValue = value
        self.delegate?.smartNode(self, didReceiveVendorMessage: response)
    }
}

extension KLMSmartNode: MeshNetworkDelegate {
    
    public func meshNetworkManager(_ manager: MeshNetworkManager, didReceiveMessage message: MeshMessage, sentFrom source: Address, to destination: Address) {
        
        ///收到回复，停止计时
        command?.commandResponseFinishWithCommand()
        switch message {
        case let message as UnknownMessage://收发消息
            if let parameters = message.parameters {
                print("messageResponse = \(parameters.hex)")
                
                if parameters.count >= 2 {
                    
                    ///不是当前节点的消息不处理
                    if source != currentNode?.unicastAddress {
                        print("Invalid message")
                        return
                    }
                    
                    var opCode: OpCodeType = .set
                    if message.opCode.hex() == "00DD00FF" {
                        print("Get messages = \(parameters.hex)")
                        opCode = .get
                    } else if message.opCode.hex() == "00DB00FF" {
                        print("Set messages = \(parameters.hex)")
                        opCode = .set
                    } else {
                        print("Invalid message")
                        return
                    }
                    ///状态 0为成功  其他为失败
                    let status = parameters[0]
                    /// dp点
                    let dpData = parameters[1]
                    /// 数据
                    let value: Data = parameters.suffix(from: 2)
                    
                    handleMessage(opcode: opCode, status: status, dpData: dpData, value: value)
                
                }
            }
        case is ConfigNodeResetStatus:
            self.delegate?.smartNodeDidResetNode(self)
        default:
            break
        }
    }
    
    public func meshNetworkManager(_ manager: MeshNetworkManager, didSendMessage message: MeshMessage, from localElement: Element, to destination: Address) {
        
        var dp1: Int?
        if let parameters = message.parameters {
            
            if parameters.count >= 1 {
                
                let dpData: Int = Int(parameters[0])
                dp1 = dpData
                if dpData == 12 {
                    command?.timeout = 20
                } else if dpData == 1 {
                    command?.timeout = 4
                } else if dpData == 26 {
                    command?.timeout = 25
                } else if dpData == 50 {
                    command?.timeout = 60
                }
            }
        }
        
        //开始计时
        command?.startTimer { [weak self] error in
            guard let self = self else { return }
            ///超时取消消息发送
            self.command?.messageHandle?.cancel()
            var error = KLMMessageError(dpId: dp1)
            let messageInfo = NSLocalizedString("Connection timed out.", comment: "") + NSLocalizedString("Make sure the device is powered on and nearby.Otherwise,check if it is connected by others or out of order.", comment: "")
            error.error = KLMError.error(messageInfo)
            self.delegate?.smartNode(self, didfailure: error)
        }
    }
    
    public func meshNetworkManager(_ manager: MeshNetworkManager, failedToSendMessage message: MeshMessage, from localElement: Element, to destination: Address, error: Error) {
        ///失败停止计时
        command?.commandResponseFinishWithCommand()
        
        var dp1: Int?
        if let parameters = message.parameters {
                        
            if parameters.count >= 1 {
                
                let dpData: Int = Int(parameters[0])
                dp1 = dpData
            }
        }
        
        var error = KLMMessageError(dpId: dp1)
        let messageInfo = NSLocalizedString("Make sure the device is powered on and nearby.Otherwise,check if it is connected by others or out of order.", comment: "")
        error.error = KLMError.error(messageInfo)
        self.delegate?.smartNode(self, didfailure: error)
    }
}

