//
//  CardDetailsViewController.swift
//  PayCardsRecognizer
//
//  Created by Vitaliy Kuzmenko on 13/07/2017.
//  Copyright © 2017 Wallet One. All rights reserved.
//

import UIKit
import PayCardsRecognizer

class CardDetailsViewController: UIViewController {

    @IBOutlet weak var holderNameTextField: UITextField!
    
    @IBOutlet weak var numberTextField: UITextField!
    
    @IBOutlet weak var expireDateTextField: UITextField!
    
    var result: PayCardsRecognizerResult!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        holderNameTextField.text = result.recognizedHolderName
        numberTextField.text = result.recognizedNumber?.format(" ")
        expireDateTextField.text = String(format: "%@/%@", result.recognizedExpireDateMonth ?? "", result.recognizedExpireDateYear ?? "")
    }

    

}
