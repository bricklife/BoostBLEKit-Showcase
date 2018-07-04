//
//  ViewController.swift
//  BoostBLEKit-Showcase
//
//  Created by Shinichiro Oba on 04/07/2018.
//  Copyright © 2018 bricklife.com. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    
    @IBOutlet weak var label: NSTextField!
    
    var power: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setPower(power: 0)
    }
    
    func setPower(power: Int) {
        self.power = power
        label.stringValue = "\(power)"
    }
    
    @IBAction func pushPlusButton(_ sender: Any) {
        let power = min(self.power + 10, 100)
        setPower(power: power)
    }
    
    @IBAction func pushMinusButton(_ sender: Any) {
        let power = max(self.power - 10, -100)
        setPower(power: power)
    }
    
    @IBAction func pushStopButton(_ sender: Any) {
        setPower(power: 0)
    }
}
