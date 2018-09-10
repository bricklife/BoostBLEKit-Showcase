//
//  ViewController.swift
//  BoostBLEKit-Showcase-macOS
//
//  Created by Shinichiro Oba on 10/07/2018.
//  Copyright © 2018 bricklife.com. All rights reserved.
//

import Cocoa
import CoreBluetooth
import BoostBLEKit

class ViewController: NSViewController {
    
    @IBOutlet weak var connectButton: NSButton!
    @IBOutlet weak var powerLabel: NSTextField!
    @IBOutlet weak var nameLabel: NSTextField!
    @IBOutlet weak var commandTextField: NSTextField!
    
    private var hubManager: HubManager!
    private var power: Int8 = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        hubManager = HubManager(delegate: self)
        
        setPower(power: 0)
        nameLabel.stringValue = ""
    }
    
    private func setPower(power: Int8) {
        self.power = power
        powerLabel.stringValue = "\(power)"
        
        guard let hub = hubManager.connectedHub else { return }
        
        let ports: [BoostBLEKit.Port] = [.A, .B, .C, .D]
        for port in ports {
            if let command = hub.motorPowerCommand(port: port, power: power) {
                hubManager.write(data: command.data)
            }
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
        guard let color = BoostBLEKit.Color(rawValue: UInt8(sender.indexOfSelectedItem)) else { return }
        if let command = hubManager.connectedHub?.rgbLightColorCommand(color: color) {
            hubManager.write(data: command.data)
        }
    }
}

extension ViewController: HubManagerDelegate {
    func didConnect(peripheral: CBPeripheral) {
        connectButton.title = "Disconnect"
        nameLabel.stringValue = peripheral.name ?? "Unknown"
    }
    
    func didFailToConnect(peripheral: CBPeripheral, error: Error?) {
        connectButton.title = "Connect"
        nameLabel.stringValue = ""
    }
    
    func didDisconnect(peripheral: CBPeripheral, error: Error?) {
        connectButton.title = "Connect"
        nameLabel.stringValue = ""
    }
}
