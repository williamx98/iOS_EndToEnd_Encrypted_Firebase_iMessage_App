//
//  LoginController.swift
//  custom_iMessage_clone
//
//  Created by William X. on 2/19/19.
//  Copyright © 2019 Will Xu . All rights reserved.
//

import UIKit
import Firebase
import SwiftyRSA
import RNCryptor

class LoginController: UIViewController {
    var messagesController: MessagesController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.darkGray
        self.view.addSubview(activityIndicator)
        self.view.addSubview(submitTypeControl)
        self.view.addSubview(fieldsView)
        self.view.addSubview(submitButton)
        self.view.addSubview(titleView)
        setupAcitivtyIndicator()
        setupTitleView()
        setupSubmitTypeControl()
        setupFieldsView()
        setupSubmitButton()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if self.view.frame.origin.y == 0 {
            self.view.frame.origin.y -= 55
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        if self.view.frame.origin.y != 0 {
            self.view.frame.origin.y = 0
        }
    }
    
    @objc func handleSubmit() {
        self.password = passwordField.text
        self.activityIndicator.startAnimating()
        if submitTypeControl.selectedSegmentIndex == 0 {
            handleLogin()
        } else {
            handleRegister()
        }
    }
    
    var password: String?
    func handleRegister() {
        guard let email = emailField.text, let password = passwordField.text, let name = nameField.text else {
            print("Error retrieveing fields")
            return
        }

        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            self.activityIndicator.stopAnimating()
            let user = authResult?.user
            if error != nil {
                self.showError(error: error!)
                return
            }
            
            guard let uid = user?.uid else {
                return
            }
            
            // Auth sucess
            let ref = Database.database().reference()
            do {
                let keyPair = try SwiftyRSA.generateRSAKeyPair(sizeInBits: 2048)
                
                let privateKey = keyPair.privateKey
                let publicKey = keyPair.publicKey
                let publicKeyString = try publicKey.base64String()
                let privateKeyString = try privateKey.base64String()
                let privateData = Data(base64Encoded: privateKeyString)!
                let encrypted = RNCryptor.encrypt(data: privateData, withPassword: self.password!)
                let encryptedString = encrypted.base64EncodedString()
                
                KeychainManager.saveToKeychain(publicKey: publicKey, privateKey: privateKey)
                
                let usersRef = ref.child("users").child(uid)
                let values = ["name": name, "email": email, "publicKeyString": publicKeyString, "privateKeyEncryptedString": encryptedString]
                usersRef.updateChildValues(values, withCompletionBlock: { (err, ref) in
                    if err != nil {
                        return
                    }
                    
                    let user = User()
                    user.setValuesForKeys(values)
                    user.privateKey = privateKey
                    
                    User.currentUser = user
                    self.messagesController?.setNavbar(user: user)
                    self.dismiss(animated: true, completion: nil)
                })
            } catch let error as NSError {
                print(error)
                return
            }
        }
    }
    
    func handleLogin() {
        guard let email = emailField.text, let password = passwordField.text else {
            print("Error retrieveing fields")
            return
        }
        
        Auth.auth().signIn(withEmail: email, password: password, completion: { (user, error) in
            self.activityIndicator.stopAnimating()
            if error != nil {
                self.showError(error: error!)
                return
            }
            self.messagesController?.fetchUserAndSetNavbar(password)
            self.dismiss(animated: true, completion: nil)
        })
    }
    
    @objc func handleSubmitTypeChange() {
        let title = submitTypeControl.titleForSegment(at: submitTypeControl.selectedSegmentIndex)
        submitButton.setTitle(title, for: .normal)
        
        fieldViewHeightAnchor?.constant = submitTypeControl.selectedSegmentIndex == 0 ? 100 : 150
        nameFieldHeightAnchor?.isActive = false
        nameFieldHeightAnchor = nameField.heightAnchor.constraint(equalTo: fieldsView.heightAnchor, multiplier: submitTypeControl.selectedSegmentIndex == 0 ? 0 : 1/3)
        nameFieldHeightAnchor?.isActive = true
        
        emailFieldHeightAnchor?.isActive = false
        emailFieldHeightAnchor = emailField.heightAnchor.constraint(equalTo: fieldsView.heightAnchor, multiplier: submitTypeControl.selectedSegmentIndex == 0 ? 1/2 : 1/3)
        emailFieldHeightAnchor?.isActive = true
        
        passwordFieldHeightAnchor?.isActive = false
        passwordFieldHeightAnchor = passwordField.heightAnchor.constraint(equalTo: fieldsView.heightAnchor, multiplier: submitTypeControl.selectedSegmentIndex == 0 ? 1/2 : 1/3)
        passwordFieldHeightAnchor?.isActive = true
    }
    
    func showError(error: Error) {
        let alertController = UIAlertController(title: error.localizedDescription, message: "", preferredStyle: .alert)
        let OKAction = UIAlertAction(title: "OK", style: .default) {(action) in self.passwordField.text = ""}
        alertController.addAction(OKAction)
        self.present(alertController, animated: true)
    }
    
    let fieldsView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 5
        view.layer.masksToBounds = true
        return view
    }()
    
    let submitButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.gray
        button.setTitle("Register", for: .normal)
        button.setTitleColor(UIColor.white, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = 5
        button.layer.masksToBounds = true
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        button.addTarget(self, action: #selector(handleSubmit), for: .touchUpInside)
        return button
    }()
    
    let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .whiteLarge)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    let titleView: UILabel = {
        let titleLabel = UILabel()
        titleLabel.text = "Friend2Friend"
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.backgroundColor = UIColor.clear
        titleLabel.textColor = UIColor.white
        titleLabel.font = UIFont.systemFont(ofSize: 200,  weight: UIFont.Weight.ultraLight)
        titleLabel.textAlignment = .center
        titleLabel.minimumScaleFactor = 0.1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.lineBreakMode = .byClipping
        titleLabel.numberOfLines = 0
        titleLabel.sizeToFit()
        return titleLabel
    }()
    
    let submitTypeControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Login", "Register"])
        sc.translatesAutoresizingMaskIntoConstraints = false
        sc.tintColor = UIColor.white
        sc.selectedSegmentIndex = 1
        sc.addTarget(self, action: #selector(handleSubmitTypeChange), for: .valueChanged)
        return sc
    }()
    
    let nameField: UITextField = {
        let field = UITextField()
        field.placeholder = "Name"
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()
    
    let emailField: UITextField = {
        let field = UITextField()
        field.placeholder = "Email"
        field.autocapitalizationType = .none
        field.keyboardType = UIKeyboardType.emailAddress
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()
    
    
    let passwordField: UITextField = {
        let field = UITextField()
        field.placeholder = "Password"
        field.isSecureTextEntry = true
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()
    
    
    let separator0: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.gray
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let separator1: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.gray
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    func setupAcitivtyIndicator() {
        activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        activityIndicator.topAnchor.constraint(equalTo: submitButton.bottomAnchor, constant: 16).isActive = true
    }
    
    func setupTitleView() {
        titleView.centerXAnchor.constraint(equalTo: fieldsView.centerXAnchor, constant: 0).isActive = true
        titleView.bottomAnchor.constraint(equalTo: submitTypeControl.topAnchor, constant: -16).isActive = true
        titleView.widthAnchor.constraint(equalTo: fieldsView.widthAnchor, constant: 0).isActive = true
        titleView.heightAnchor.constraint(equalToConstant: 65).isActive = true
    }
    
    func setupSubmitTypeControl() {
        submitTypeControl.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0).isActive = true
        submitTypeControl.bottomAnchor.constraint(equalTo: fieldsView.topAnchor, constant: -16).isActive = true
        submitTypeControl.widthAnchor.constraint(equalTo: fieldsView.widthAnchor, multiplier: 0.5, constant: 0).isActive = true
        submitTypeControl.heightAnchor.constraint(equalToConstant: 25).isActive = true
    }
    
    var fieldViewHeightAnchor: NSLayoutConstraint?
    var nameFieldHeightAnchor: NSLayoutConstraint?
    var emailFieldHeightAnchor: NSLayoutConstraint?
    var passwordFieldHeightAnchor: NSLayoutConstraint?
    
    func setupFieldsView() {
        fieldsView.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0).isActive = true
        fieldsView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 0).isActive = true
        fieldsView.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -32).isActive = true
        fieldViewHeightAnchor = fieldsView.heightAnchor.constraint(equalToConstant: 150)
        fieldViewHeightAnchor?.isActive = true
        
        fieldsView.addSubview(nameField)
        nameField.leftAnchor.constraint(equalTo: fieldsView.leftAnchor, constant: 12).isActive = true
        nameField.topAnchor.constraint(equalTo: fieldsView.topAnchor, constant: 0).isActive = true
        nameField.widthAnchor.constraint(equalTo: fieldsView.widthAnchor, constant: 0).isActive = true
        nameFieldHeightAnchor = nameField.heightAnchor.constraint(equalTo: fieldsView.heightAnchor, multiplier: 1/3, constant: 0)
        nameFieldHeightAnchor?.isActive = true
        
        fieldsView.addSubview(separator0)
        separator0.leftAnchor.constraint(equalTo: fieldsView.leftAnchor, constant: 0).isActive = true
        separator0.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 0).isActive = true
        separator0.widthAnchor.constraint(equalTo: fieldsView.widthAnchor, constant: 0).isActive = true
        separator0.heightAnchor.constraint(equalToConstant: 1).isActive = true
        
        fieldsView.addSubview(emailField)
        emailField.leftAnchor.constraint(equalTo: fieldsView.leftAnchor, constant: 12).isActive = true
        emailField.topAnchor.constraint(equalTo: separator0.bottomAnchor, constant: 0).isActive = true
        emailField.widthAnchor.constraint(equalTo: fieldsView.widthAnchor, constant: 0).isActive = true
        emailFieldHeightAnchor = emailField.heightAnchor.constraint(equalTo: fieldsView.heightAnchor, multiplier: 1/3, constant: 0)
        emailFieldHeightAnchor?.isActive = true
        
        fieldsView.addSubview(separator1)
        separator1.leftAnchor.constraint(equalTo: fieldsView.leftAnchor, constant: 0).isActive = true
        separator1.topAnchor.constraint(equalTo: emailField.bottomAnchor, constant: 0).isActive = true
        separator1.widthAnchor.constraint(equalTo: fieldsView.widthAnchor, constant: 0).isActive = true
        separator1.heightAnchor.constraint(equalToConstant: 1).isActive = true
        
        fieldsView.addSubview(passwordField)
        passwordField.leftAnchor.constraint(equalTo: fieldsView.leftAnchor, constant: 12).isActive = true
        passwordField.topAnchor.constraint(equalTo: separator1.bottomAnchor, constant: 0).isActive = true
        passwordField.widthAnchor.constraint(equalTo: fieldsView.widthAnchor, constant: 0).isActive = true
        passwordFieldHeightAnchor = passwordField.heightAnchor.constraint(equalTo: fieldsView.heightAnchor, multiplier: 1/3, constant: 0)
        passwordFieldHeightAnchor?.isActive = true
    }
    
    func setupSubmitButton() {
        submitButton.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0).isActive = true
        submitButton.topAnchor.constraint(equalTo: fieldsView.bottomAnchor, constant: 12).isActive = true
        submitButton.widthAnchor.constraint(equalTo: fieldsView.widthAnchor, multiplier: 0.5, constant: 0).isActive = true
        submitButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
}
