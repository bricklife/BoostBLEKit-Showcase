//
//  ViewController.swift
//  BoostBLEKit-Showcase-iOS
//
//  Created by Shinichiro Oba on 10/07/2018.
//  Copyright © 2018 bricklife.com. All rights reserved.
//

import UIKit
import CoreBluetooth
import BoostBLEKit

class ViewController: UIViewController {

    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var powerLabel: UILabel!
    @IBOutlet weak var commandTextField: UITextField!
    
    private var hubManager: HubManager!
    private var power: Int8 = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        hubManager = HubManager(delegate: self)
        
        setPower(power: 0)
        nameLabel.text = ""
    }
    
    private func setPower(power: Int8) {
        self.power = power
        powerLabel.text = "\(power)"
        
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
        if let data = commandTextField.text.flatMap(Data.init(hexString:)) {
            hubManager.write(data: data)
        }
    }
}

extension ViewController: HubManagerDelegate {
    func didConnect(peripheral: CBPeripheral) {
        connectButton.setTitle("Disconnect", for: .normal)
        nameLabel.text = peripheral.name ?? "Unknown"
    }
    
    func didFailToConnect(peripheral: CBPeripheral, error: Error?) {
        connectButton.setTitle("Connect", for: .normal)
        nameLabel.text = ""
    }
    
    func didDisconnect(peripheral: CBPeripheral, error: Error?) {
        connectButton.setTitle("Connect", for: .normal)
        nameLabel.text = ""
    }
}

