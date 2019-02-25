//
//  UserCell.swift
//  custom_iMessage_clone
//
//  Created by William X. on 2/21/19.
//  Copyright © 2019 Will Xu . All rights reserved.
//

import UIKit
import Firebase

class UserCell: UITableViewCell {
    var message: Message? {
        didSet {
            setupName()
        }
    }
    
    private func setupName() {
        if let toId = message?.chatPartnerId() {
            let ref = Database.database().reference().child("users").child(toId)
            ref.observeSingleEvent(of: .value) { (snapshot) in
                if let dic = snapshot.value as? [String: Any] {
                    self.textLabel?.text = dic["name"] as? String
                }
            }
        }
        detailTextLabel?.text = message?.text
        
        if let seconds = message?.timestamp?.doubleValue {
            let ts = Date(timeIntervalSince1970: seconds)
            let dateFormat = DateFormatter()
            dateFormat.dateFormat = "h:mm a"
            timeLabel.text = dateFormat.string(from: ts)
        }
    }
    
    let timeLabel: UILabel = {
        let label = UILabel()
//        label.text = "HH:MM"
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = UIColor.lightGray
        label.textAlignment = .right
        label.font = UIFont.systemFont(ofSize: 14)
        return label
    }()
    
    override func layoutSubviews() {
        super.layoutSubviews()
        textLabel?.frame = CGRect(x: 16, y: 5, width: textLabel!.frame.width, height: textLabel!.frame.height)
        textLabel?.font = UIFont.systemFont(ofSize: (textLabel?.font.pointSize)!,  weight: UIFont.Weight.semibold)
        detailTextLabel?.frame = CGRect(x: 16, y: 27, width: detailTextLabel!.frame.width, height: detailTextLabel!.frame.height)
        detailTextLabel?.textColor = UIColor.gray
        detailTextLabel?.font = UIFont.systemFont(ofSize: (textLabel?.font.pointSize)! - 2)
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        self.layoutSubviews()
        addSubview(timeLabel)
        timeLabel.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -16).isActive = true
        timeLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 5).isActive = true
        timeLabel.widthAnchor.constraint(equalToConstant: 100).isActive = true
        timeLabel.heightAnchor.constraint(equalTo: (textLabel?.heightAnchor)!).isActive = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init not declared")
    }
}

