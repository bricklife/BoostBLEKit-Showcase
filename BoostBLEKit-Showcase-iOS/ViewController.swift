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
    @IBOutlet weak var firmwareVersionLabel: UILabel!
    @IBOutlet weak var batteryLabel: UILabel!
    @IBOutlet weak var powerLabel: UILabel!
    @IBOutlet weak var commandTextField: UITextField!
    
    private var hubManager: HubManager!
    private var power: Int8 = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        hubManager = HubManager(delegate: self)
        
        resetLabels()
        
        setPower(power: 0)
    }
    
    private func resetLabels() {
        nameLabel.text = ""
        firmwareVersionLabel.text = ""
        batteryLabel.text = ""
    }
    
    private func setPower(power: Int8) {
        self.power = power
        powerLabel.text = "\(power)"
        
        let ports: [BoostBLEKit.Port] = [.A, .B, .C, .D]
        for (uuid, hub) in hubManager.connectedHub {
            for port in ports {
                if let command = hub.motorStartPowerCommand(port: port, power: power) {
                    hubManager.write(uuid: uuid, data: command.data)
                }
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
            for uuid in hubManager.connectedHub.keys {
                hubManager.write(uuid: uuid, data: data)
            }
        }
    }

    var color = 0
    
    @IBAction func pushColorButton(_ sender: Any) {
        guard let color = BoostBLEKit.Color(rawValue: UInt8(self.color)) else { return }
        for (uuid, hub) in hubManager.connectedHub {
            if let command = hub.rgbLightColorCommand(color: color) {
                hubManager.write(uuid: uuid, data: command.data)
            }
        }
        self.color = (self.color + 1) % 11
    }
}

extension ViewController: HubManagerDelegate {
    func didConnect(peripheral: CBPeripheral) {
        connectButton.setTitle("Disconnect", for: .normal)
        nameLabel.text = peripheral.name ?? "Unknown"
    }
    
    func didFailToConnect(peripheral: CBPeripheral, error: Error?) {
        connectButton.setTitle("Connect", for: .normal)
        resetLabels()
    }
    
    func didDisconnect(peripheral: CBPeripheral, error: Error?) {
        connectButton.setTitle("Connect", for: .normal)
        resetLabels()
    }
    
    func didUpdate(notification: BoostBLEKit.Notification) {
        switch notification {
        case .hubProperty(let hubProperty, let value):
            switch hubProperty {
            case .advertisingName:
                nameLabel.text = value.stringValue
            case .firmwareVersion:
                firmwareVersionLabel.text = "F/W: \(value.stringValue)"
            case .batteryVoltage:
                batteryLabel.text = "Battery: \(value.stringValue) %"
            default:
                break
            }
            
        default:
            break
        }
    }
}

