//
//  InterfaceController.swift
//  BoostBLEKit-Showcase-watchOS Extension
//
//  Created by Shinichiro Oba on 21/02/2019.
//  Copyright © 2019 bricklife.com. All rights reserved.
//

import WatchKit
import Foundation
import CoreBluetooth
import BoostBLEKit

class InterfaceController: WKInterfaceController {
    
    @IBOutlet weak var connectButton: WKInterfaceButton!
    @IBOutlet weak var powerLabel: WKInterfaceLabel!
    
    private var hubManager: HubManager!
    private var power: Int8 = 0
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        hubManager = HubManager(delegate: self)
        
        setPower(power: 0)
    }
    
    private func setPower(power: Int8) {
        self.power = power
        powerLabel.setText("\(power)")
        
        guard let hub = hubManager.connectedHub else { return }
        
        let ports: [BoostBLEKit.Port] = [.A, .B, .C, .D]
        for port in ports {
            if let command = hub.motorPowerCommand(port: port, power: power) {
                hubManager.write(data: command.data)
            }
        }
    }
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    @IBAction func pushConnectButton() {
        if hubManager.isConnectedHub {
            hubManager.disconnect()
        } else {
            hubManager.startScan()
        }
    }
    
    @IBAction func pushPlusButton() {
        let power = min(self.power + 10, 100)
        setPower(power: power)
    }
    
    @IBAction func pushMinusButton() {
        let power = max(self.power - 10, -100)
        setPower(power: power)
    }
    
    @IBAction func pushStopButton() {
        setPower(power: 0)
    }
}

extension InterfaceController: HubManagerDelegate {
    func didConnect(peripheral: CBPeripheral) {
        connectButton.setTitle("Disconnect")
    }
    
    func didFailToConnect(peripheral: CBPeripheral, error: Error?) {
        connectButton.setTitle("Connect")
    }
    
    func didDisconnect(peripheral: CBPeripheral, error: Error?) {
        connectButton.setTitle("Connect")
    }
}
