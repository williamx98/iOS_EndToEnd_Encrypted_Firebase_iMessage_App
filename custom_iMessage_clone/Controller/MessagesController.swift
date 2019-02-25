//
//  ViewController.swift
//  custom_iMessage_clone
//
//  Created by William X. on 2/19/19.
//  Copyright © 2019 Will Xu . All rights reserved.
//

import UIKit
import Firebase
import SwiftyRSA
import RNCryptor

class MessagesController: UITableViewController {
    let cellId = "cellId"
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.darkGray
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Logout", style: .plain, target: self, action: #selector(handleLogout))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(handleNewMessage))
        self.tableView.tableFooterView = UIView()
        tableView.register(UserCell.self, forCellReuseIdentifier: cellId)

        checkIfUserloggedIn()
    }
    
    var messages = [Message]()
    var messagesDict = [String: Message]()
    
    func observeUserMessages() {
        guard let uid = Auth.auth().currentUser?.uid else {
            return
        }
        
        let ref = Database.database().reference().child("user-messages").child(uid)
        ref.observe(.childAdded, with: { (snapshot) in
            let userId = snapshot.key
            ref.child(userId).observe(.childAdded, with: { (snapshot) in
                let messageId = snapshot.key
                let messagesRef = Database.database().reference().child("messages").child(messageId)
                
                messagesRef.observeSingleEvent(of: .value, with: { (snapshot) in
                    if let dic = snapshot.value as? [String: Any] {
                        let message = Message()
                        message.setValuesForKeys(dic)
                        if message.fromId == Auth.auth().currentUser?.uid {
                            message.text = Message.toDecryptedString(encrypted: message.fromText!, privateKey: (User.currentUser?.privateKey!)!)
                        } else {
                            message.text = Message.toDecryptedString(encrypted: message.toText!, privateKey: (User.currentUser?.privateKey!)!)
                        }
                        
                        if let chatPartnerId = message.chatPartnerId() {
                            self.messagesDict[chatPartnerId] = message
                        }
                        
                        self.attemptReload()
                    }
                }, withCancel: nil)
            }, withCancel: nil)
        }, withCancel: nil)
        
        ref.observe(.childRemoved, with: { (snapshot) in
            self.messagesDict.removeValue(forKey: snapshot.key)
            self.attemptReload()
        }, withCancel: nil)
    }
    
    var timer: Timer?
    
    func attemptReload() {
        self.timer?.invalidate()
        print(self.messagesDict)
        self.timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.handleReload), userInfo: nil, repeats: false)
    }
    
    @objc func handleReload() {
        self.messages = Array(self.messagesDict.values)
        self.messages.sort(by: { (message1, message2) -> Bool in
            return (message1.timestamp?.intValue)! > (message2.timestamp?.intValue)!
        })
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard let uid = Auth.auth().currentUser?.uid else {
            return
        }
        
        let message = self.messages[indexPath.row]
        
        if let chatPartnerId = message.chatPartnerId() {
            Database.database().reference().child("user-messages").child(uid).child(message.chatPartnerId()!).removeValue { (error
                , snapshot) in
                if error != nil {
                    print(error)
                    return
                }
                
                self.messagesDict.removeValue(forKey: chatPartnerId)
                self.attemptReload()
            }
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! UserCell
        let message = messages[indexPath.row]
        cell.message = message
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 72
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let message = messages[indexPath.row]
        guard let chatPartnerId = message.chatPartnerId() else {
            return
        }
        
        let ref = Database.database().reference().child("users").child(chatPartnerId)
        ref.observeSingleEvent(of: .value, with: { (snapshot) in
            guard let dict = snapshot.value as? [String: AnyObject] else {
                return
            }
            
            let user = User()
            user.id = chatPartnerId
            user.setValuesForKeys(dict)
            self.showChatController(user: user)
        }, withCancel: nil)
    }
    
    @objc func handleNewMessage() {
        let newMessagesController = NewMessagesController()
        newMessagesController.messagesController = self
        let navController = UINavigationController(rootViewController: newMessagesController)
        present(navController, animated: true, completion: nil)
    }
    
    func goToLogin() {
        perform(#selector(handleLogout), with: nil, afterDelay: 0)
    }
    
    func checkIfUserloggedIn() {
        if Auth.auth().currentUser?.uid == nil {
            self.goToLogin()
        } else {
            fetchUserAndSetNavbar()
        }
    }
    
    func fetchUserAndSetNavbar(_ password: String? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else {
            self.goToLogin()
            return
        }
        
        Database.database().reference().child("users").child(uid).observeSingleEvent(of: .value, with: { (snapshot) in
            if let dic = snapshot.value as? [String: Any] {
                let user = User()
                user.setValuesForKeys(dic)
                
                do {
                    let privateKey: PrivateKey?
                    if (password != nil) {
                        let privateKeyEncryptedString = user.privateKeyEncryptedString
                        let privateKeyEncrytptedData = Data(base64Encoded: privateKeyEncryptedString!)
                        let privateKeyData = try RNCryptor.decrypt(data: privateKeyEncrytptedData!, withPassword: password!)
                        let privateKeyString = privateKeyData.base64EncodedString()
                        privateKey = try PrivateKey(base64Encoded: privateKeyString)
                        
                        KeychainManager.saveToKeychain(publicKey: user.publicKey!, privateKey: privateKey!)
                    } else {
                        privateKey = KeychainManager.getPrivateKey()
                    }
                    
                    user.privateKey = privateKey
                    User.currentUser = user
                    self.setNavbar(user: User.currentUser!)
                } catch let error as NSError {
                    print(error)
                    return
                }
            }
        }, withCancel: nil)
    }
    
    func setNavbar(user: User) {
        messages.removeAll()
        messagesDict.removeAll()
        tableView.reloadData()
        observeUserMessages()
        
        let titleView = UIView()
        
        titleView.frame = CGRect(x: 0, y: 0, width: 100, height: 40)
        titleView.translatesAutoresizingMaskIntoConstraints = false
        titleView.backgroundColor = UIColor.clear
        
        let containerView = UIView()
        titleView.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.centerXAnchor.constraint(equalTo: titleView.centerXAnchor, constant: 0).isActive = true
        containerView.heightAnchor.constraint(equalTo: titleView.heightAnchor).isActive = true
        containerView.widthAnchor.constraint(equalTo: titleView.widthAnchor).isActive = true
        containerView.centerYAnchor.constraint(equalTo: titleView.centerYAnchor, constant: 0).isActive = true
        
        
        let nameLabel = UILabel()
        containerView.addSubview(nameLabel)
        nameLabel.text = user.name
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor, constant: 0).isActive = true
        nameLabel.heightAnchor.constraint(equalTo: containerView.heightAnchor).isActive = true
        nameLabel.widthAnchor.constraint(equalTo: containerView.widthAnchor).isActive = true
        nameLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: 0).isActive = true
        
        self.navigationItem.titleView = titleView
        
    }
    
    @objc func showChatController(user: User) {
        let chatLogController = ChatLogController(collectionViewLayout: UICollectionViewFlowLayout())
        chatLogController.user = user
        navigationController?.pushViewController(chatLogController, animated: true)
    }

    @objc func handleLogout() {
        do {
            try Auth.auth().signOut()
        } catch let error {
            print(error)
        }
        
        let loginController = LoginController()
        User.currentUser = nil
        KeychainManager.deleteFromKeychain()
        loginController.messagesController = self
        present(loginController, animated: true, completion: nil)
    }

}
