//
//  Message.swift
//  custom_iMessage_clone
//
//  Created by William X. on 2/21/19.
//  Copyright © 2019 Will Xu . All rights reserved.
//
import UIKit
import Firebase
import SwiftyRSA

class Message: NSObject {
    @objc var fromId: String?
    @objc var toText: String?
    @objc var fromText: String?
    @objc var timestamp: NSNumber?
    @objc var toId: String?
    
    var text: String?
    
    @objc func chatPartnerId() -> String? {
        if fromId == Auth.auth().currentUser?.uid {
            return (self.toId)!
        } else {
            return (self.fromId)!
        }
    }
    
    static func toEncryptedString(raw: String, publicKey: PublicKey) -> String? {
        do {
            let data = try ClearMessage(string: raw, using: .utf8)
            let encrypted = try data.encrypted(with: publicKey, padding: .PKCS1)
            return encrypted.base64String
        } catch let error as NSError {
            print(error)
            return nil
        }
    }
    
    static func toDecryptedString(encrypted: String, privateKey: PrivateKey) -> String? {
        do {
            let data = try EncryptedMessage(base64Encoded: encrypted)
            let decrypted = try data.decrypted(with: privateKey, padding: .PKCS1)
            return try decrypted.string(encoding: .utf8)
        } catch let error as NSError {
            print(error)
            return nil
        }
    }
}
