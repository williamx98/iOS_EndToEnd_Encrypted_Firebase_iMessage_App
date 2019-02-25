//
//  KeychainManager.swift
//  custom_iMessage_clone
//
//  Created by William X. on 2/24/19.
//  Copyright © 2019 Will Xu . All rights reserved.
//

import UIKit
import SwiftyRSA
import KeychainSwift

class KeychainManager: NSObject {    
    static func saveToKeychain(publicKey: PublicKey, privateKey: PrivateKey) {
        do {
            let keychain = KeychainSwift()
            keychain.set(try publicKey.base64String(), forKey: Bundle.main.bundleIdentifier! + "publicKey")
            keychain.set(try privateKey.base64String(), forKey: Bundle.main.bundleIdentifier! + "privateKey")
        } catch let error as NSError {
            print(error)
            return
        }
    }
    
    static func getPublicKey() -> PublicKey? {
        do {
            let keychain = KeychainSwift()
            let public64String = keychain.get(Bundle.main.bundleIdentifier! + "publicKey")
            let publicKey = try PublicKey(base64Encoded: public64String!)
            return publicKey
        } catch let error as NSError {
            print(error)
            return nil
        }
    }
    
    static func getPrivateKey() -> PrivateKey? {
        do {
            let keychain = KeychainSwift()
            let private64String = keychain.get(Bundle.main.bundleIdentifier! + "privateKey")
            let privateKey = try PrivateKey(base64Encoded: private64String!)
            return privateKey
        } catch let error as NSError {
            print(error)
            return nil
        }
    }
    
    static func deleteFromKeychain() {
        let keychain = KeychainSwift()
        keychain.clear()
    }
    
}
