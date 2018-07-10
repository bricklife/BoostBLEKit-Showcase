//
//  ViewController.swift
//  BoostBLEKit-Showcase
//
//  Created by Shinichiro Oba on 04/07/2018.
//  Copyright © 2018 bricklife.com. All rights reserved.
//

import Cocoa
import BoostBLEKit
import CoreBluetooth

class ViewController: NSViewController {
    
    @IBOutlet weak var connectButton: NSButton!
    @IBOutlet weak var powerLabel: NSTextField!
    @IBOutlet weak var nameTextField: NSTextField!
    @IBOutlet weak var commandTextField: NSTextField!
    
    private var hubManager: HubManager!
    private var power: Int8 = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        hubManager = HubManager(delegate: self)
        
        setPower(power: 0)
        nameTextField.stringValue = ""
    }
    
    private func setPower(power: Int8) {
        self.power = power
        powerLabel.stringValue = "\(power)"
        
        for motor in hubManager.motors.values {
            let command = motor.powerCommand(power: power)
            hubManager.write(data: command.data)
        }
    }
    
    @IBAction func pushConnectButton(_ sender: Any) {
        if hubManager.isConnectedHub {
            hubManager.disconnect()
        } else {
            hubManager.startScan()
        }
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
    
    @IBAction func pushSendButton(_ sender: Any) {
        if let data = Data(hexString: commandTextField.stringValue) {
            hubManager.write(data: data)
        }
    }
    
    @IBAction func changeColorPopup(_ sender: NSPopUpButton) {
        if let color = RGBLightColorCommand.Color(rawValue: UInt8(sender.indexOfSelectedItem)),
            let command = hubManager.rgbLight?.colorCommand(color: color) {
            hubManager.write(data: command.data)
        }
    }
}

extension ViewController: HubManagerDelegate {
    func didConnect(peripheral: CBPeripheral) {
        connectButton.title = "Disconnect"
    }
    
    func didFailToConnect(peripheral: CBPeripheral, error: Error?) {
        connectButton.title = "Connect"
    }
    
    func didDisconnect(peripheral: CBPeripheral, error: Error?) {
        connectButton.title = "Connect"
    }
}
