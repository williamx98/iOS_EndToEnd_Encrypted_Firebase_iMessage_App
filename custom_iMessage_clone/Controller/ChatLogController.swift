//
//  ChatLogController.swift
//  custom_iMessage_clone
//
//  Created by William X. on 2/20/19.
//  Copyright © 2019 Will Xu . All rights reserved.
//

import UIKit
import Firebase

class ChatLogController: UICollectionViewController, UITextFieldDelegate, UICollectionViewDelegateFlowLayout {
    var user: User? {
        didSet {
            navigationItem.title = user?.name
            observeMessages()
        }
    }
    
    var messages = [Message]()
    var width = UIScreen.main.bounds.width
    func observeMessages() {
        guard let uid = Auth.auth().currentUser?.uid, let toId = user?.id else {return}
        
        let userMessagesRef = Database.database().reference().child("user-messages").child(uid).child(toId)
        userMessagesRef.observe(.childAdded, with: { (snapshot) in
            let messageId = snapshot.key
            let messagesRef = Database.database().reference().child("messages").child(messageId)
            messagesRef.observeSingleEvent(of: .value, with: { (snapshot) in
                guard let dict = snapshot.value as? [String: AnyObject] else {return}
                
                let message = Message()
                message.setValuesForKeys(dict)
                if message.fromId == Auth.auth().currentUser?.uid {
                    message.text = Message.toDecryptedString(encrypted: message.fromText!, privateKey: (User.currentUser?.privateKey!)!)
                } else {
                    message.text = Message.toDecryptedString(encrypted: message.toText!, privateKey: (User.currentUser?.privateKey!)!)
                }
                self.messages.append(message)
                
                DispatchQueue.main.async {
                    self.collectionView?.reloadData()
                }
            
            }, withCancel: nil)
        }, withCancel: nil)
    }
    
    lazy var input: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Message..."
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self
        return textField
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView?.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        collectionView?.alwaysBounceVertical = true
        collectionView?.backgroundColor = UIColor.white
        collectionView?.register(MessageCell.self, forCellWithReuseIdentifier: cellId)
        collectionView?.keyboardDismissMode = .interactive
    }
    
    lazy var inputContainerView: UIView = {
        let container = UIView()
        container.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 40)
        container.backgroundColor = UIColor.white.withAlphaComponent(0.96)
        
        let line = UIView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.backgroundColor = UIColor(red: 210/255, green: 210/255, blue: 210/255, alpha: 1)
        container.addSubview(line)
        line.leftAnchor.constraint(equalTo: container.leftAnchor).isActive = true
        line.rightAnchor.constraint(equalTo: container.rightAnchor).isActive = true
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        line.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
        
        let send = UIButton(type: .system)
        container.addSubview(send)
        send.setTitle("Send", for: .normal)
        send.translatesAutoresizingMaskIntoConstraints = false
        send.rightAnchor.constraint(equalTo: container.rightAnchor).isActive = true
        send.centerYAnchor.constraint(equalTo: container.centerYAnchor).isActive = true
        send.widthAnchor.constraint(equalToConstant: 80).isActive = true
        send.heightAnchor.constraint(equalTo: container.widthAnchor).isActive = true
        send.addTarget(self, action: #selector(handleSend), for: .touchUpInside)
        
        container.addSubview(input)
        self.input.leftAnchor.constraint(equalTo: container.leftAnchor, constant: 16).isActive = true
        self.input.centerYAnchor.constraint(equalTo: container.centerYAnchor).isActive = true
        self.input.rightAnchor.constraint(equalTo: send.leftAnchor, constant: 0).isActive = true
        self.input.heightAnchor.constraint(equalTo: container.heightAnchor).isActive = true
        
        return container
    }()
    
    override var inputAccessoryView: UIView? {
        get {
            return inputContainerView
        }
    }
    
    override var canBecomeFirstResponder: Bool {
        get {
            return true
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        self.width = size.width
        self.collectionView.collectionViewLayout.invalidateLayout()
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }
    
    func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    var containerViewBottomAnchor: NSLayoutConstraint?
    @objc func handleKeyboardWillShow(notification: NSNotification) {
        let keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue
        containerViewBottomAnchor?.constant = -keyboardFrame!.height
        UIView.animate(withDuration: duration!) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func handleKeyboardWillHide(notification: NSNotification) {
        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue
        containerViewBottomAnchor?.constant = 0
        UIView.animate(withDuration: duration!) {
            self.view.layoutIfNeeded()
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.messages.count
    }
    
    var visibleRows: [IndexPath]?
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { context in
            self.visibleRows = self.collectionView.indexPathsForVisibleItems
            context.viewController(forKey: UITransitionContextViewControllerKey.from)
        }, completion: { context in
            self.collectionView.scrollToItem(at: (self.visibleRows?[self.visibleRows!.count - 1])!, at: .top, animated: false)
        })
    }
    
    let cellId = "cellId"
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as! MessageCell
        let message = messages[indexPath.item]
        setupCell(cell: cell, message: message)
        
        return cell
    }
    
    private func setupCell(cell: MessageCell, message: Message) {
        if message.fromId == Auth.auth().currentUser?.uid {
            cell.bubbleView.backgroundColor = MessageCell.blueColor
            cell.textView.textColor = UIColor.white
            cell.bubbleViewRightAnchor?.isActive = true
            cell.bubbleViewLeftAnchor?.isActive = false
        } else {
            cell.bubbleView.backgroundColor = UIColor(red: 230/255, green: 230/255, blue: 230/255, alpha: 1)
            cell.textView.textColor = UIColor.black
            cell.bubbleViewRightAnchor?.isActive = false
            cell.bubbleViewLeftAnchor?.isActive = true
        }
        
        if message.text != nil {
            cell.bubbleWidthAnchor?.constant = estimateFrame(text: message.text!).width + 32
            cell.textView.text = message.text!
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var height: CGFloat = 80
        
        if let text = messages[indexPath.item].text {
            height = estimateFrame(text: text).height + 18
        }
        
        
        return CGSize(width: self.width, height: height)
    }
    
    private func estimateFrame(text: String) -> CGRect {
        let size = CGSize(width:  self.width/1.5, height: 1000)
        let options = NSStringDrawingOptions.usesFontLeading.union(.usesLineFragmentOrigin)
        
        return NSString(string: text).boundingRect(with: size, options: options, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16)], context: nil)
    }
    
    @objc func handleSend() {
        let ref = Database.database().reference().child("messages")
        let childRef = ref.childByAutoId()
        let toId = user!.id!
        let fromId = Auth.auth().currentUser!.uid
        let timestamp = Int(NSDate().timeIntervalSince1970)
        let rawText = input.text!
        let publicKey = user?.publicKey
        let encryptedString = Message.toEncryptedString(raw: rawText, publicKey: publicKey!)
        
        let selfPublicKey = User.currentUser?.publicKey
        let selfEncryptedString = Message.toEncryptedString(raw: rawText, publicKey: selfPublicKey!)
        let values = ["toText": encryptedString!, "fromText": selfEncryptedString!,"toId": toId, "fromId": fromId, "timestamp": timestamp] as [String : Any]
        
        childRef.updateChildValues(values) { (error, ref) in
            if error != nil {
                print(error!)
                return
            }
            
            guard let messageId = childRef.key else { return }
            
            let userMessagesRef = Database.database().reference().child("user-messages").child(fromId).child(toId).child(messageId)
            userMessagesRef.setValue(true)
            
            let toMessagesRef = Database.database().reference().child("user-messages").child(toId).child(fromId).child(messageId)
            toMessagesRef.setValue(true)

        }
    
        input.text = nil
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        handleSend()
        return true
    }
}
