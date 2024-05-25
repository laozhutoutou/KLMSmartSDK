//
//  KLMError.swift
//  KLMSmartSDK
//
//  Created by zhu yu on 2024/5/13.
//

import Foundation

public enum KLMError: Error {
    case modelNotFound
    case timeout
    case invalidParameter
    case error(String?)
}

extension KLMError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .timeout:
            return NSLocalizedString("Request timed out.", comment: "")
        case .modelNotFound:
            return NSLocalizedString("Model not found.", comment: "")
        case .error(let msg):
            return msg
        case .invalidParameter:
            return NSLocalizedString("Invalid parameter.", comment: "")
        }
    }
}

public struct KLMMessageError {
    var errorCode: Int?
    var dpId: Int?
    var error: Error?
}
