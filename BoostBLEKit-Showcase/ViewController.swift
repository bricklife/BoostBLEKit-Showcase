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

struct MoveHubService {
    
    static let serviceUuid = CBUUID(string: GATT.serviceUuid)
    static let characteristicUuid = CBUUID(string: GATT.characteristicUuid)
}

class ViewController: NSViewController {
    
    @IBOutlet weak var connectButton: NSButton!
    @IBOutlet weak var label: NSTextField!
    @IBOutlet weak var textField: NSTextField!
    
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    
    private var motors: [BoostBLEKit.Port : Motor] = [:]
    private var rgbLight: RGBLight?
    private var power: Int8 = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        setPower(power: 0)
    }
    
    private func setPower(power: Int8) {
        self.power = power
        label.stringValue = "\(power)"
        
        for motor in motors.values {
            let command = motor.powerCommand(power: power)
            write(data: command.data)
        }
    }
    
    func startScan() {
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [MoveHubService.serviceUuid], options: nil)
        }
    }
    
    func stopScan() {
        centralManager.stopScan()
    }
    
    func connect(peripheral: CBPeripheral) {
        if self.peripheral == nil {
            self.peripheral = peripheral
            centralManager.connect(peripheral, options: nil)
            connectButton.title = "Disconnect"
        }
    }
    
    func disconnect() {
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
            self.peripheral = nil
            self.characteristic = nil
            connectButton.title = "Connect"
        }
    }
    
    func set(characteristic: CBCharacteristic) {
        if let peripheral = peripheral, characteristic.properties.contains([.write, .notify]) {
            self.characteristic = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }
    
    func receive(notification: BoostBLEKit.Notification) {
        switch notification {
        case .connected(let port, let deviceType):
            print("connected:", port, deviceType)
            if let motor = Motor(port: port, deviceType: deviceType) {
                motors[port] = motor
            }
            if let rgbLight = RGBLight(port: port, deviceType: deviceType) {
                self.rgbLight = rgbLight
            }
        case .disconnected(let port):
            motors[port] = nil
            print("disconnected:", port)
        }
    }
    
    func write(data: Data) {
        print("<", data.hexString)
        if let peripheral = peripheral, let characteristic = characteristic {
            DispatchQueue.main.async {
                peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
            }
        }
    }
    
    @IBAction func pushConnectButton(_ sender: Any) {
        if peripheral == nil {
            startScan()
        } else {
            disconnect()
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
        if let data = Data(hexString: textField.stringValue) {
            write(data: data)
        }
    }

    @IBAction func changeColorPopup(_ sender: NSPopUpButton) {
        if let color = RGBLightColorCommand.Color(rawValue: UInt8(sender.indexOfSelectedItem)),
            let command = rgbLight?.colorCommand(color: color) {
            write(data: command.data)
        }
    }
}

extension ViewController: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            print("unknown")
        case .resetting:
            print("resetting")
        case .unsupported:
            print("unsupported")
        case .unauthorized:
            print("unauthorized")
        case .poweredOff:
            print("poweredOff")
        case .poweredOn:
            print("poweredOn")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        connect(peripheral: peripheral)
        stopScan()
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([MoveHubService.serviceUuid])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print(#function, peripheral.identifier, error ?? "nil")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print(#function, peripheral.identifier, error ?? "nil")
    }
}

extension ViewController: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let service = peripheral.services?.first(where: { $0.uuid == MoveHubService.serviceUuid }) {
            peripheral.discoverCharacteristics([MoveHubService.characteristicUuid], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristic = service.characteristics?.first(where: { $0.uuid == MoveHubService.characteristicUuid }) {
            set(characteristic: characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        print(">", data.hexString)
        if let notification = Notification(data: data) {
            receive(notification: notification)
        }
    }
}
